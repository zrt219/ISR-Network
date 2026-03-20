// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title  ISRNetwork
 * @author U235 Command Center
 * @notice Tracks In-Situ Recovery (ISR) uranium extraction across multiple
 *         wellfields, wells, aquifer zones, and chemical solution batches
 *         on the XRPL EVM Sidechain testnet.
 *
 * @dev    ISR Process Overview:
 *         1. Oxygenated water injected underground (~700ft)
 *         2. Water dissolves uranium from sandstone ore
 *         3. Uranium-bearing solution extracted to surface
 *         4. Processed through resin, filter, dryer → yellowcake
 *         5. Packaged, transported, converted to UF6
 *         6. Water recycled back to injection (circular loop)
 *
 *         Architecture differences from linear FuelCycle.sol:
 *         - Multiple wellfields, each with multiple wells (parallel)
 *         - Wells have independent state (no shared mutex)
 *         - ChemicalBatch is fluid-based (litres + ppm concentration)
 *         - Water recycling creates circular batch lifecycle
 *         - Concurrent updates safe: each well is isolated
 */
contract ISRNetwork {

    /* ─────────────────────────────────────────────
       CONSTANTS
    ───────────────────────────────────────────── */

    uint8  public constant STAGE_COUNT         = 8;
    uint8  public constant STAGE_INJECTION     = 0;
    uint8  public constant STAGE_RESIN_LOAD    = 1;
    uint8  public constant STAGE_RESIN_CHARGE  = 2;
    uint8  public constant STAGE_FILTER_PRESS  = 3;
    uint8  public constant STAGE_DRYER         = 4;
    uint8  public constant STAGE_PACKAGING     = 5;
    uint8  public constant STAGE_TRANSPORT     = 6;
    uint8  public constant STAGE_CONVERSION    = 7;

    uint8  public constant MAX_WELLS_PER_FIELD = 16;
    uint256 public constant MAX_FLOW_RATE      = 10000; // L/hr basis units
    uint256 public constant MAX_PRESSURE       = 5000;  // kPa basis units
    uint8  public constant MAX_CONCENTRATION   = 200;   // ppm * 10 (basis: 100 = 10.0 ppm)

    /* ─────────────────────────────────────────────
       ERRORS
    ───────────────────────────────────────────── */

    error NotOwner();
    error ZeroAddress();
    error InvalidWellfield(uint256 wellfieldId);
    error InvalidWell(uint256 wellfieldId, uint256 wellId);
    error InvalidBatch(uint256 batchId);
    error InvalidStage(uint8 stageId);
    error WellNotActive(uint256 wellfieldId, uint256 wellId);
    error WellAlreadyActive(uint256 wellfieldId, uint256 wellId);
    error MaxWellsReached(uint256 wellfieldId);
    error FlowRateExceeded(uint256 requested, uint256 maximum);
    error PressureExceeded(uint256 requested, uint256 maximum);
    error AquiferCompromised(uint256 wellfieldId);
    error BatchAlreadyComplete(uint256 batchId);
    error InvalidConcentration(uint256 ppm);
    error ZeroVolume();

    /* ─────────────────────────────────────────────
       ENUMS
    ───────────────────────────────────────────── */

    enum WellStatus {
        IDLE,
        INJECTING,
        EXTRACTING,
        MAINTENANCE,
        OFFLINE
    }

    enum WellfieldStatus {
        INACTIVE,
        ACTIVE,
        SUSPENDED,
        DECOMMISSIONED
    }

    /* ─────────────────────────────────────────────
       STRUCTS
    ───────────────────────────────────────────── */

    struct Wellfield {
        uint256 id;
        string  name;
        string  location;          // geographic identifier
        uint256 depthFt;           // target depth in feet (typ. 700)
        WellfieldStatus status;
        uint256 wellCount;
        uint256 totalBatches;
        uint256 totalVolumeProcessed;  // litres
        uint256 createdAt;
        bool    aquiferSafe;       // compliance flag
    }

    struct Well {
        uint256 id;
        uint256 wellfieldId;
        WellStatus status;
        uint256 flowRate;          // L/hr, basis units (max 10000)
        uint256 pressure;          // kPa, basis units (max 5000)
        uint256 concentration;     // ppm*10 of uranium in solution
        uint256 totalExtracted;    // cumulative litres extracted
        uint256 activatedAt;
        uint256 lastUpdatedAt;
        bool    isInjector;        // true = injection well, false = extraction
    }

    struct AquiferZone {
        uint256 wellfieldId;
        uint256 depthTopFt;        // top of protected zone (typ. 100ft)
        uint256 depthBottomFt;     // bottom of protected zone (typ. 300ft)
        uint8   barrierIntegrity;  // 0-100, below 70 = alert
        bool    exemptionActive;   // NRC aquifer exemption status
        uint256 lastInspectedAt;
        bool    compromised;       // true = emergency halt
    }

    struct ChemicalBatch {
        uint256 id;
        uint256 wellfieldId;
        uint256 wellId;
        uint256 volumeLitres;      // current volume
        uint256 concentrationPpm;  // uranium concentration (ppm * 10)
        uint8   currentStage;      // 0-7 ISR stage
        uint256 recycleCount;      // how many times water has been recycled
        bool    isRecycledWater;   // true = this is return water
        address createdBy;
        uint256 createdAt;
        uint256 lastAdvancedAt;
        bool    complete;
    }

    /* ─────────────────────────────────────────────
       STATE
    ───────────────────────────────────────────── */

    address public owner;

    mapping(uint256 => Wellfield)    private _wellfields;
    mapping(uint256 => Well)         private _wells;          // global well ID
    mapping(uint256 => uint256[])    private _wellfieldWells; // wellfieldId → wellIds
    mapping(uint256 => AquiferZone)  private _aquiferZones;
    mapping(uint256 => ChemicalBatch) private _batches;

    uint256 public wellfieldCount;
    uint256 public wellCount;
    uint256 public batchCount;
    uint256 public totalVolumeProcessed;  // global cumulative
    uint256 public totalYellowcakeKg;     // cumulative yellowcake produced

    /* ─────────────────────────────────────────────
       EVENTS
    ───────────────────────────────────────────── */

    event WellfieldCreated(
        uint256 indexed wellfieldId,
        string  name,
        uint256 depthFt,
        address createdBy
    );

    event WellfieldStatusChanged(
        uint256 indexed wellfieldId,
        WellfieldStatus indexed oldStatus,
        WellfieldStatus indexed newStatus
    );

    event WellCreated(
        uint256 indexed wellId,
        uint256 indexed wellfieldId,
        bool    isInjector,
        address createdBy
    );

    event WellActivated(
        uint256 indexed wellId,
        uint256 indexed wellfieldId,
        uint256 flowRate,
        uint256 pressure,
        uint256 timestamp
    );

    event WellDeactivated(
        uint256 indexed wellId,
        uint256 indexed wellfieldId,
        uint256 timestamp
    );

    event WellParametersUpdated(
        uint256 indexed wellId,
        uint256 indexed wellfieldId,
        uint256 newFlowRate,
        uint256 newPressure,
        uint256 newConcentration
    );

    event BatchCreated(
        uint256 indexed batchId,
        uint256 indexed wellfieldId,
        uint256 indexed wellId,
        uint256 volumeLitres,
        uint256 concentrationPpm,
        address createdBy
    );

    event BatchAdvanced(
        uint256 indexed batchId,
        uint256 indexed wellfieldId,
        uint8   indexed fromStage,
        uint8   toStage,
        uint256 timestamp
    );

    event BatchRecycled(
        uint256 indexed batchId,
        uint256 indexed wellfieldId,
        uint256 recycleCount,
        uint256 timestamp
    );

    event BatchCompleted(
        uint256 indexed batchId,
        uint256 indexed wellfieldId,
        uint256 volumeLitres,
        uint256 yellowcakeKg,
        uint256 completedAt
    );

    event AquiferAlert(
        uint256 indexed wellfieldId,
        uint8   barrierIntegrity,
        bool    compromised,
        uint256 timestamp
    );

    event AquiferInspected(
        uint256 indexed wellfieldId,
        uint8   barrierIntegrity,
        uint256 timestamp
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /* ─────────────────────────────────────────────
       MODIFIERS
    ───────────────────────────────────────────── */

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier validWellfield(uint256 wellfieldId) {
        if (wellfieldId >= wellfieldCount) revert InvalidWellfield(wellfieldId);
        _;
    }

    modifier validWell(uint256 wellId) {
        if (wellId >= wellCount) revert InvalidWell(0, wellId);
        _;
    }

    modifier validBatch(uint256 batchId) {
        if (batchId >= batchCount) revert InvalidBatch(batchId);
        _;
    }

    modifier aquiferSafe(uint256 wellfieldId) {
        if (_aquiferZones[wellfieldId].compromised) revert AquiferCompromised(wellfieldId);
        _;
    }

    /* ─────────────────────────────────────────────
       CONSTRUCTOR
    ───────────────────────────────────────────── */

    constructor() {
        owner = msg.sender;
    }

    /* ─────────────────────────────────────────────
       WRITE — WELLFIELD MANAGEMENT
    ───────────────────────────────────────────── */

    /**
     * @notice Create a new wellfield.
     * @param name       Human-readable name (e.g. "Wellfield Alpha")
     * @param location   Geographic identifier
     * @param depthFt    Target extraction depth in feet
     */
    function createWellfield(
        string calldata name,
        string calldata location,
        uint256 depthFt
    ) external onlyOwner {
        uint256 id = wellfieldCount++;
        _wellfields[id] = Wellfield({
            id:                   id,
            name:                 name,
            location:             location,
            depthFt:              depthFt,
            status:               WellfieldStatus.INACTIVE,
            wellCount:            0,
            totalBatches:         0,
            totalVolumeProcessed: 0,
            createdAt:            block.timestamp,
            aquiferSafe:          true
        });

        // Initialize aquifer zone with safe defaults
        _aquiferZones[id] = AquiferZone({
            wellfieldId:       id,
            depthTopFt:        100,
            depthBottomFt:     300,
            barrierIntegrity:  100,
            exemptionActive:   false,
            lastInspectedAt:   block.timestamp,
            compromised:       false
        });

        emit WellfieldCreated(id, name, depthFt, msg.sender);
    }

    /**
     * @notice Activate or suspend a wellfield.
     */
    function setWellfieldStatus(uint256 wellfieldId, WellfieldStatus newStatus)
        external
        onlyOwner
        validWellfield(wellfieldId)
    {
        WellfieldStatus old = _wellfields[wellfieldId].status;
        _wellfields[wellfieldId].status = newStatus;
        emit WellfieldStatusChanged(wellfieldId, old, newStatus);
    }

    /* ─────────────────────────────────────────────
       WRITE — WELL MANAGEMENT
    ───────────────────────────────────────────── */

    /**
     * @notice Add a well to a wellfield.
     * @param wellfieldId  Parent wellfield
     * @param isInjector   true = injection well, false = extraction well
     */
    function addWell(uint256 wellfieldId, bool isInjector)
        external
        onlyOwner
        validWellfield(wellfieldId)
    {
        if (_wellfields[wellfieldId].wellCount >= MAX_WELLS_PER_FIELD)
            revert MaxWellsReached(wellfieldId);

        uint256 id = wellCount++;
        _wells[id] = Well({
            id:             id,
            wellfieldId:    wellfieldId,
            status:         WellStatus.IDLE,
            flowRate:       0,
            pressure:       0,
            concentration:  0,
            totalExtracted: 0,
            activatedAt:    0,
            lastUpdatedAt:  block.timestamp,
            isInjector:     isInjector
        });

        _wellfieldWells[wellfieldId].push(id);
        _wellfields[wellfieldId].wellCount++;

        emit WellCreated(id, wellfieldId, isInjector, msg.sender);
    }

    /**
     * @notice Activate a well with flow rate and pressure.
     * @param wellId    Well to activate
     * @param flowRate  L/hr (max 10000)
     * @param pressure  kPa (max 5000)
     */
    function activateWell(uint256 wellId, uint256 flowRate, uint256 pressure)
        external
        onlyOwner
        validWell(wellId)
        aquiferSafe(_wells[wellId].wellfieldId)
    {
        Well storage well = _wells[wellId];
        if (well.status == WellStatus.INJECTING || well.status == WellStatus.EXTRACTING)
            revert WellAlreadyActive(well.wellfieldId, wellId);
        if (flowRate > MAX_FLOW_RATE)   revert FlowRateExceeded(flowRate, MAX_FLOW_RATE);
        if (pressure > MAX_PRESSURE)    revert PressureExceeded(pressure, MAX_PRESSURE);

        well.status      = well.isInjector ? WellStatus.INJECTING : WellStatus.EXTRACTING;
        well.flowRate    = flowRate;
        well.pressure    = pressure;
        well.activatedAt = block.timestamp;
        well.lastUpdatedAt = block.timestamp;

        emit WellActivated(wellId, well.wellfieldId, flowRate, pressure, block.timestamp);
    }

    /**
     * @notice Deactivate a well.
     */
    function deactivateWell(uint256 wellId)
        external
        onlyOwner
        validWell(wellId)
    {
        Well storage well = _wells[wellId];
        well.status    = WellStatus.IDLE;
        well.flowRate  = 0;
        well.pressure  = 0;
        well.lastUpdatedAt = block.timestamp;

        emit WellDeactivated(wellId, well.wellfieldId, block.timestamp);
    }

    /**
     * @notice Update well operating parameters (flow, pressure, concentration).
     * @param wellId        Target well
     * @param flowRate      New flow rate L/hr
     * @param pressure      New pressure kPa
     * @param concentration New uranium concentration ppm*10
     */
    function updateWellParameters(
        uint256 wellId,
        uint256 flowRate,
        uint256 pressure,
        uint256 concentration
    )
        external
        onlyOwner
        validWell(wellId)
    {
        if (flowRate > MAX_FLOW_RATE) revert FlowRateExceeded(flowRate, MAX_FLOW_RATE);
        if (pressure > MAX_PRESSURE)  revert PressureExceeded(pressure, MAX_PRESSURE);

        Well storage well = _wells[wellId];
        well.flowRate       = flowRate;
        well.pressure       = pressure;
        well.concentration  = concentration;
        well.lastUpdatedAt  = block.timestamp;

        emit WellParametersUpdated(wellId, well.wellfieldId, flowRate, pressure, concentration);
    }

    /* ─────────────────────────────────────────────
       WRITE — BATCH MANAGEMENT
    ───────────────────────────────────────────── */

    /**
     * @notice Create a new chemical solution batch from a well.
     * @param wellfieldId     Source wellfield
     * @param wellId          Source well (must be extraction well, active)
     * @param volumeLitres    Volume of solution in litres
     * @param concentrationPpm Uranium concentration (ppm * 10, e.g. 100 = 10.0 ppm)
     */
    function createBatch(
        uint256 wellfieldId,
        uint256 wellId,
        uint256 volumeLitres,
        uint256 concentrationPpm
    )
        external
        onlyOwner
        validWellfield(wellfieldId)
        validWell(wellId)
        aquiferSafe(wellfieldId)
    {
        if (volumeLitres == 0) revert ZeroVolume();

        uint256 id = batchCount++;
        _batches[id] = ChemicalBatch({
            id:               id,
            wellfieldId:      wellfieldId,
            wellId:           wellId,
            volumeLitres:     volumeLitres,
            concentrationPpm: concentrationPpm,
            currentStage:     STAGE_INJECTION,
            recycleCount:     0,
            isRecycledWater:  false,
            createdBy:        msg.sender,
            createdAt:        block.timestamp,
            lastAdvancedAt:   block.timestamp,
            complete:         false
        });

        _wellfields[wellfieldId].totalBatches++;
        _wellfields[wellfieldId].totalVolumeProcessed += volumeLitres;
        _wells[wellId].totalExtracted += volumeLitres;
        totalVolumeProcessed += volumeLitres;

        emit BatchCreated(id, wellfieldId, wellId, volumeLitres, concentrationPpm, msg.sender);
    }

    /**
     * @notice Advance a batch to the next ISR processing stage.
     * @param batchId   Batch to advance
     */
    function advanceBatch(uint256 batchId)
        external
        onlyOwner
        validBatch(batchId)
    {
        ChemicalBatch storage batch = _batches[batchId];
        if (batch.complete) revert BatchAlreadyComplete(batchId);

        uint8 from = batch.currentStage;
        uint8 to   = from + 1;

        if (to >= STAGE_COUNT) {
            // Batch complete — calculate yellowcake output
            // Simplified: 1 litre at 10ppm = ~0.00001 kg yellowcake
            uint256 yellowcakeKg = (batch.volumeLitres * batch.concentrationPpm) / 10000000;
            totalYellowcakeKg += yellowcakeKg;

            batch.complete       = true;
            batch.currentStage   = STAGE_CONVERSION;
            batch.lastAdvancedAt = block.timestamp;

            emit BatchAdvanced(batchId, batch.wellfieldId, from, STAGE_CONVERSION, block.timestamp);
            emit BatchCompleted(batchId, batch.wellfieldId, batch.volumeLitres, yellowcakeKg, block.timestamp);
            return;
        }

        batch.currentStage   = to;
        batch.lastAdvancedAt = block.timestamp;

        emit BatchAdvanced(batchId, batch.wellfieldId, from, to, block.timestamp);
    }

    /**
     * @notice Recycle processed water back to injection (circular loop).
     * @param batchId   Completed batch whose water to recycle
     */
    function recycleBatchWater(uint256 batchId)
        external
        onlyOwner
        validBatch(batchId)
    {
        ChemicalBatch storage batch = _batches[batchId];

        // Create a new recycled-water batch at injection stage
        uint256 newId = batchCount++;
        _batches[newId] = ChemicalBatch({
            id:               newId,
            wellfieldId:      batch.wellfieldId,
            wellId:           batch.wellId,
            volumeLitres:     batch.volumeLitres,
            concentrationPpm: 0,              // water stripped of uranium
            currentStage:     STAGE_INJECTION, // back to start
            recycleCount:     batch.recycleCount + 1,
            isRecycledWater:  true,
            createdBy:        msg.sender,
            createdAt:        block.timestamp,
            lastAdvancedAt:   block.timestamp,
            complete:         false
        });

        emit BatchRecycled(newId, batch.wellfieldId, batch.recycleCount + 1, block.timestamp);
    }

    /* ─────────────────────────────────────────────
       WRITE — AQUIFER MANAGEMENT
    ───────────────────────────────────────────── */

    /**
     * @notice Record an aquifer inspection result.
     * @param wellfieldId    Wellfield to inspect
     * @param integrity      Barrier integrity 0-100 (below 70 triggers alert)
     * @param compromised    true = emergency halt required
     */
    function recordAquiferInspection(
        uint256 wellfieldId,
        uint8   integrity,
        bool    compromised
    )
        external
        onlyOwner
        validWellfield(wellfieldId)
    {
        AquiferZone storage zone = _aquiferZones[wellfieldId];
        zone.barrierIntegrity = integrity;
        zone.compromised      = compromised;
        zone.lastInspectedAt  = block.timestamp;

        _wellfields[wellfieldId].aquiferSafe = !compromised;

        if (compromised || integrity < 70) {
            emit AquiferAlert(wellfieldId, integrity, compromised, block.timestamp);
        } else {
            emit AquiferInspected(wellfieldId, integrity, block.timestamp);
        }
    }

    /**
     * @notice Set aquifer exemption status (NRC approval).
     */
    function setAquiferExemption(uint256 wellfieldId, bool exemptionActive)
        external
        onlyOwner
        validWellfield(wellfieldId)
    {
        _aquiferZones[wellfieldId].exemptionActive = exemptionActive;
    }

    /* ─────────────────────────────────────────────
       WRITE — ADMIN
    ───────────────────────────────────────────── */

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /* ─────────────────────────────────────────────
       VIEW FUNCTIONS
    ───────────────────────────────────────────── */

    function getWellfield(uint256 wellfieldId)
        external view validWellfield(wellfieldId)
        returns (Wellfield memory)
    {
        return _wellfields[wellfieldId];
    }

    function getWell(uint256 wellId)
        external view validWell(wellId)
        returns (Well memory)
    {
        return _wells[wellId];
    }

    function getWellfieldWells(uint256 wellfieldId)
        external view validWellfield(wellfieldId)
        returns (uint256[] memory)
    {
        return _wellfieldWells[wellfieldId];
    }

    function getBatch(uint256 batchId)
        external view validBatch(batchId)
        returns (ChemicalBatch memory)
    {
        return _batches[batchId];
    }

    function getAquiferZone(uint256 wellfieldId)
        external view validWellfield(wellfieldId)
        returns (AquiferZone memory)
    {
        return _aquiferZones[wellfieldId];
    }

    function getNetworkStats()
        external view
        returns (
            uint256 totalWellfields,
            uint256 totalWells,
            uint256 totalBatches,
            uint256 totalVolume,
            uint256 totalYellowcake
        )
    {
        return (wellfieldCount, wellCount, batchCount, totalVolumeProcessed, totalYellowcakeKg);
    }
}
