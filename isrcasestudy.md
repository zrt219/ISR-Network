# CASE STUDY · FULL-STACK WEB3 DAPP

# ISR NETWORK

**Proving parallel multi-well In-Situ Recovery tracking on a next-generation EVM-compatible ledger — immutable underground operations on-chain.**

---

## Stack

- XRPL EVM
- Solidity 0.8.24
- ethers.js v5
- Canvas 2D
- Three.js
- Foundry
- Vercel

---

## Deployment

- **Live:** https://isr-network.vercel.app/
- **Contract:** `0xa766e45193e562A934AD2cb1994c8f9007faA897`
- **Chain ID:** `1449000` (XRPL EVM Testnet)

---

## Key Metrics

| Metric | Value |
|---|---|
| Contract | Solidity 0.8.24 |
| Pipeline Stages | 8 (Injection → Conversion) |
| Well Architecture | 4+ wells, parallel concurrent execution |
| Deploy Time | < 5 minutes |
| Frontend | Full wallet-connected simulation UI |
| Write Surface | 8 write functions |
| Read Surface | 6 read panels |

---

# ⛏ Executive Summary

ISR Network is a production-grade, fully on-chain control system for In-Situ Recovery uranium extraction deployed to the XRPL EVM Sidechain testnet.

Unlike conventional uranium mining, ISR injects oxygenated water roughly 700 feet underground into sandstone-hosted ore bodies. The solution dissolves uranium in situ, is pumped back to surface through extraction wells, processed across eight operational stages, and then recycled back into the system. The project models that full operational loop directly on-chain.

The contract tracks:

- multiple wellfields
- independent injector and extractor wells
- chemical solution batches
- uranium concentration in solution using integer ppm encoding
- aquifer integrity and exemption state
- recycled water lifecycle state
- batch advancement from injection through conversion

Every operation is an immutable on-chain event and storage transition.

This build also had to solve the defining XRPL EVM problem: the chain does not implement `eth_estimateGas` or `eth_gasPrice` at the RPC layer. That breaks normal assumptions in both ethers.js and Foundry because both attempt these calls automatically before transactions. The result is silent failure unless every write path is explicitly overridden with hardcoded gas settings.

Beyond chain quirks, ISR Network introduced a more difficult contract architecture than a normal linear lifecycle system. Instead of one object moving through one state machine, the system coordinates multiple wells operating in parallel under a single wellfield safety domain. That requires independent well state, independent batch state, and a global aquifer gate that can halt new activity at the field level without a shared execution mutex.

The result is a full-stack Web3 application that demonstrates:

- parallel on-chain system design
- non-standard EVM chain debugging
- deterministic frontend state updates
- MetaMask-connected production UX
- custom simulation UI tied to live contract reads and writes

---

# ⛏ Problem Statement

ISR is the fastest-growing method of uranium extraction globally and now accounts for more than half of world uranium production. Despite its scale, operational complexity, and environmental sensitivity, key records across the lifecycle are still typically managed through paper logs, siloed enterprise software, and fragmented operator reporting.

That creates four structural problems:

## 1. Compliance history is weak

Aquifer exemption records and barrier integrity inspections need durable historical tracking. Paper logs and private databases do not provide tamper-resistant chronology.

## 2. Uranium concentration data matters

The uranium content in solution has direct regulatory significance. Concentration values are not cosmetic metadata; they are part of the operational truth of the system.

## 3. Water recycling must be provable

ISR depends on significant water reuse. If water reclamation and reinjection are tracked loosely, environmental accountability becomes weak.

## 4. Multiple operators need shared truth

Injection and extraction infrastructure may be handled by different roles or entities. Without a common state layer, reconciliation becomes trust-based instead of system-based.

### Why on-chain ISR is meaningful

An on-chain model gives:

- immutable operational history
- consistent state visibility across actors
- deterministic lifecycle tracking
- event-based auditability
- clearer compliance posture for inspections and reviews

---

# ⛏ Solidity Architecture

## Contract Design

- `pragma solidity 0.8.24`
- no OpenZeppelin
- no external dependencies
- single-file deterministic contract
- native arithmetic safety from Solidity 0.8.x
- reduced dependency risk and bytecode ambiguity

XRPL EVM targets London-era compatibility. That matters because newer opcode assumptions from Shanghai/Cancun cannot be relied on.

---

## System Model

This is **not** a linear state machine.

The hierarchy is:

```text
Wellfield → Well[] → ChemicalBatch[]
             └──── AquiferZone
```

Each entity has its own storage identity and lifecycle.

### Core mappings

```solidity
mapping(uint256 => Wellfield) private _wellfields;
mapping(uint256 => Well) private _wells;
mapping(uint256 => ChemicalBatch) private _batches;
mapping(uint256 => AquiferZone) private _aquiferZones;
mapping(uint256 => uint256[]) private _wellfieldWells;
```

### Why this matters

The key architectural difference from simpler contracts is that wells operate concurrently. That means:

- one well can activate while another is already active
- batches belong to specific wells, not to a single global conveyor
- storage writes must be isolated by ID
- safety checks must gate the whole wellfield without entangling local well state

This is a parallel system design problem, not a sequential workflow problem.

---

## Contract Hierarchy

```text
ISRNetwork
├── Wellfield
│   ├── id
│   ├── name
│   ├── location
│   ├── depthFt
│   ├── status
│   ├── wellCount
│   └── aquiferSafe
├── Well
│   ├── flowRate
│   ├── pressure
│   ├── concentration
│   ├── status
│   └── isInjector
├── AquiferZone
│   ├── barrierIntegrity
│   ├── exemptionActive
│   └── compromised
└── ChemicalBatch
    ├── volumeLitres
    ├── concentrationPpm
    ├── currentStage
    ├── recycleCount
    └── lifecycle flags
```

---

## ChemicalBatch Struct

```solidity
struct ChemicalBatch {
    uint256 id;
    uint256 wellfieldId;
    uint256 wellId;
    uint256 volumeLitres;      // litres, not tonnes
    uint256 concentrationPpm;  // stored ×10
    uint8 currentStage;        // 0–7
    uint256 recycleCount;
    bool isRecycledWater;
    address createdBy;
    uint256 createdAt;
    uint256 lastAdvancedAt;
    bool complete;
}
```

### Encoding note

`concentrationPpm` is stored using integer ×10 encoding.

Example:

- stored value `120` = `12.0 ppm`

This is the same fundamental pattern used elsewhere on EVM systems when representing decimal-like values without floats.

---

## Custom Errors

```solidity
error NotOwner();
error ZeroAddress();
error InvalidWellfield(uint256 wellfieldId);
error InvalidWell(uint256 wellfieldId, uint256 wellId);
error InvalidBatch(uint256 batchId);
error WellAlreadyActive(uint256 wellfieldId, uint256 wellId);
error MaxWellsReached(uint256 wellfieldId);
error FlowRateExceeded(uint256 requested, uint256 maximum);
error PressureExceeded(uint256 requested, uint256 maximum);
error AquiferCompromised(uint256 wellfieldId);
error BatchAlreadyComplete(uint256 batchId);
error ZeroVolume();
```

These errors are not just gas-efficient; they enforce crisp failure semantics for a system with many preconditions.

---

## Aquifer Safety Modifier

```solidity
modifier aquiferSafe(uint256 wellfieldId) {
    if (_aquiferZones[wellfieldId].compromised) {
        revert AquiferCompromised(wellfieldId);
    }
    _;
}
```

### Why this pattern is critical

A single aquifer inspection can flip the entire operational posture of a wellfield.

Once `compromised == true`:

- new well activations are blocked
- new batch creation is blocked
- the safety state propagates immediately at the modifier level
- no secondary synchronization call is needed

That creates a clean global gate across a parallel local architecture.

---

## Events

```solidity
event WellCreated(uint256 indexed wellId, uint256 indexed wellfieldId, bool isInjector, address createdBy);
event WellActivated(uint256 indexed wellId, uint256 indexed wellfieldId, uint256 flowRate, uint256 pressure, uint256 timestamp);
event WellDeactivated(uint256 indexed wellId, uint256 indexed wellfieldId, uint256 timestamp);
event BatchCreated(uint256 indexed batchId, uint256 indexed wellfieldId, uint256 indexed wellId, uint256 volumeLitres, uint256 concentrationPpm, uint256 timestamp);
event BatchAdvanced(uint256 indexed batchId, uint256 indexed wellfieldId, uint8 indexed fromStage, uint8 toStage, uint256 timestamp);
event BatchCompleted(uint256 indexed batchId, uint256 indexed wellfieldId, uint256 volumeLitres, uint256 yellowcakeKg, uint256 completedAt);
event BatchRecycled(uint256 indexed batchId, uint256 indexed wellfieldId, uint256 recycleCount, uint256 timestamp);
event AquiferAlert(uint256 indexed wellfieldId, uint8 barrierIntegrity, bool compromised, uint256 timestamp);
```

The event surface turns the system into an auditable operational log, not just a state store.

---

# ⛏ XRPL EVM Chain Specifics

## Chain profile

| Property | Value |
|---|---|
| Architecture | EVM execution layer on XRP Ledger using Cosmos SDK |
| Chain ID | 1449000 |
| EVM Level | London |
| Transaction Type | Legacy only (Type 0) |
| EIP-1559 | Not usable here |
| `eth_estimateGas` | Not implemented |
| `eth_gasPrice` | Not implemented |
| Minimum Global Fee | `30000000000000000 wei` |

---

## Practical consequence

Most tooling assumes gas estimation exists.

XRPL EVM breaks that assumption.

### What fails by default

- MetaMask transaction preparation can surface internal JSON-RPC errors
- ethers.js write calls can fail before submission
- Foundry simulations may hang or fail silently
- scripts that work on Ethereum or Sepolia can break with no obvious contract bug

### Required override pattern

Every transaction path must explicitly set:

```js
gasLimit: 300000
gasPrice: ethers.utils.parseUnits("100", "gwei")
```

And when using Foundry on this chain, the transaction configuration must also be aligned with legacy transaction behavior.

---

## ethers.js loading rule

The frontend must load the **UMD build** of ethers.js synchronously and only run app logic after the script exists on `window`.

### Correct rule set

- use `ethers.umd.min.js`
- do not use `defer`
- do not use `async`
- do not dynamically inject the script late
- place the application inline script at the bottom of `<body>`

### Failure mode

If not, runtime breaks with:

```text
ethers is not defined
```

This sounds trivial, but on a static-hosted frontend with inline contract logic, it becomes a hard blocker across the entire app:

- wallet connection fails
- read functions fail
- write functions fail
- event-driven UI never boots

---

# ⛏ Frontend System Design

The UI is not a generic form wrapper. It functions as an operational console.

## Surfaces

### Write surfaces

The app exposes operational write actions such as:

- create wellfield
- add well
- activate well
- deactivate well
- create batch
- advance batch
- recycle batch
- record aquifer inspection

### Read surfaces

The app also exposes structured read panels for:

- network stats
- wellfield state
- well state
- batch state
- aquifer state
- lifecycle and simulation visibility

---

## Rendering model

The simulation and dashboard update in real time, but the browser architecture had to avoid layout churn.

The final rendering pattern uses:

- pre-rendered DOM containers
- in-place `textContent` mutation
- in-place width/style mutation
- no repeated `innerHTML` rebuilds in hot loops

This is critical because the simulation updates frequently. Rebuilding DOM in a high-frequency loop caused visible page shaking and panel instability.

---

## Simulation layer

The frontend combines:

- Canvas 2D
- Three.js
- animated fluid-like underground motion
- surface farm scene
- fullscreen interaction mode

This was not just cosmetic. The simulation anchors the operational metaphor of the system and makes the parallel wells legible in a way raw tables do not.

---

# ⛏ Build Log — Engineering War Diary

This section matters because it shows the real engineering process rather than a polished final state.

The single most repeated class of bug was **not contract logic**. It was **system integration**: chain quirks, ABI drift, script timing, and DOM architecture.

---

## Issue 1 — `activateWell` reverts with `InvalidWell`

### Symptom

`activateWell()` failed immediately after deployment.

### Root cause

The contract did not seed wells at deployment. `activateWell()` assumes the target `wellId` already exists.

The frontend initially exposed activation but did not expose the `addWell()` prerequisite.

### Why this happened

ABI-level visibility does not reveal lifecycle prerequisites. The function existed and looked callable, but the true dependency chain was:

```text
createWellfield → addWell → activateWell
```

Without the intermediate object creation, the call was invalid by design.

### Fix

- add explicit `addWell()` UI panel
- document canonical setup order
- restructure the frontend so the write flow mirrors contract state prerequisites

### Production lesson

**Build UI in prerequisite order, not alphabetic function order.**

A contract can be technically complete while the product flow is still wrong.

---

## Issue 2 — `ethers is not defined`

### Symptom

Wallet connect, reads, and writes all failed at runtime.

### Root cause

The ethers CDN script was loading asynchronously because it used `defer`, and the inline application script executed before `ethers` existed on `window`.

There was also an earlier build where the inline script lived mid-body, increasing timing ambiguity.

### Fix

- remove `defer`
- use UMD build
- move inline application script to bottom of `<body>`
- ensure synchronous script load before app boot

### Why it was expensive

The failure message was simple, but the impact was total:

- no contract instance
- no provider flow
- no signer
- no reads
- no writes

This bug class had already appeared in the predecessor project and still resurfaced because frontend script ordering errors are easy to reintroduce.

### Production lesson

**Treat library loading order as part of application architecture, not HTML trivia.**

---

## Issue 3 — `CALL_EXCEPTION` on read functions

### Symptom

Read calls like `getNetworkStats()` failed or returned useless output.

### Root cause

The frontend contract constant still pointed to the zero address placeholder from the template.

### Why this is dangerous

Calling a zero-address contract often does not produce the kind of loud failure developers expect. Instead, it can look like a broken read surface with vague call exceptions or empty return behavior.

### Fix

Replace the placeholder with the verified deployed address:

```text
0xa766e45193e562A934AD2cb1994c8f9007faA897
```

### Production lesson

**Always validate deployment address wiring first after deploy.**  
A wrong address can impersonate a frontend or ABI bug.

---

## Issue 4 — page shaking during batch tracker updates

### Symptom

The UI visibly shifted and jittered during live updates.

### Root cause

`renderBatchList()` rebuilt panel contents using `innerHTML` multiple times per second. That destroyed and recreated DOM nodes continuously, forcing layout recalculation and repaint churn.

### Why it matters

In a static app with simulation + dashboards, high-frequency DOM rebuilds create a product that feels broken even if logic is technically correct.

### Fix

- pre-render fixed slots at initialization
- update only `textContent`
- update only width/style on existing elements
- eliminate repeated `innerHTML` writes in hot paths

### Production lesson

**On live dashboards, mutate nodes in place. Never rebuild the tree unless structure actually changed.**

---

## Issue 5 — compliance panel text jumping every tick

### Symptom

Barrier integrity text wrapped and shifted every update cycle.

### Root cause

`buildCompliance()` was being called inside the simulation tick loop, which rebuilt the panel repeatedly.

### Fix

- gate panel construction with a `children.length === 0` style initialization check
- only update leaf text values after first render

### Why this matters

This is a classic architecture bug: using a render function as if it were both initializer and updater.

### Production lesson

Split **initial render** from **state update** paths.

---

## Issue 6 — `BigNumber.toNumber()` failures

### Symptom

Read panels broke on numeric fields.

### Root cause

ethers `BigNumber.toNumber()` throws when a value exceeds JavaScript safe integer bounds.

Even if many current values seem small, any `uint256` return should be treated as potentially unsafe for direct numeric conversion.

### Fix

Replace:

```js
value.toNumber()
```

With:

```js
parseInt(value.toString(), 10)
```

Or preserve string form when precision matters.

### Production lesson

**Never trust `toNumber()` on contract data unless you have formally bounded the value range.**

---

## Issue 7 — ABI missing `addWell`

### Symptom

Runtime error:

```text
contract.addWell is not a function
```

### Root cause

The frontend ABI array did not include the `addWell(uint256,bool)` entry, even though the contract had the function.

### Why this happened

Manual ABI maintenance drifted away from the compiled source.

### Fix

- add the missing ABI entry
- add `writeAddWell()` implementation
- wire the new HTML panel
- move toward regenerating ABI from artifacts, not memory

### Production lesson

**The ABI is an interface artifact, not handwritten documentation. Generate it from source every time.**

---

# ⛏ Engineering Principles

## 1. Read preconditions before building UI

A write function may look independent but still depend on prior state. Contract modifiers and object existence requirements determine UX order.

## 2. Do not use `innerHTML` in high-frequency update paths

It is a layout invalidation tool, not a live dashboard strategy.

## 3. Script loading is part of correctness

A perfectly valid contract and ABI do not matter if the runtime library boot sequence is wrong.

## 4. Zero-address contract constants are silent system killers

Always verify contract wiring before debugging logic.

## 5. Treat all contract numbers as big values first

Convert safely. Preserve strings when needed. Only narrow when justified.

## 6. Parallel systems need isolated keys

Concurrent writes become tractable when state domains are separated cleanly by global IDs.

## 7. ABI discipline prevents phantom frontend bugs

A missing ABI entry creates a fake product bug even when the contract is correct.

---

# ⛏ Production Architecture — Forward Look

The current build proves the operational model. The next layer would harden it.

## Ownership

Replace the single EOA owner with multi-sig governance such as Gnosis Safe.

This matters because operations like well activation and batch creation represent regulated process actions, not casual admin clicks.

## Access Control

Introduce role separation such as:

- `ADMIN_ROLE`
- `WELLFIELD_OPERATOR_ROLE`
- `BATCH_CREATOR_ROLE`
- `COMPLIANCE_ROLE`

This prevents over-centralized permissions and maps better to real industrial workflows.

## Oracle Integration

Integrate price and assay data sources, including:

- uranium spot price references
- UF6 pricing
- validated concentration feeds from lab systems

## NFT Provenance

Mint ERC-721 tokens on batch completion, where metadata includes:

- wellfield
- well
- full stage timeline
- final concentration
- recovered output

This turns provenance into a portable asset layer.

## ZK Compliance

Add proof systems that can show threshold compliance without revealing exact sensitive measurements.

Example:

- prove aquifer integrity ≥ threshold
- without disclosing the exact integrity score

## Cross-chain bridge

Bridge provenance assets to mainnet ecosystems for broader composability and collateralization experiments.

## Generalization

The hierarchy is portable to other industries:

- oil field → drill → barrel batch
- water utility → pump → flow batch
- pharma plant → reactor → synthesis batch

The pattern is larger than uranium. ISR Network is one instance of a broader industrial on-chain operations design.

---

# ⛏ Final Outcome

ISR Network was built end-to-end as a fully functioning full-stack Web3 application with:

- verified contract deployment
- live Vercel-hosted frontend
- MetaMask interaction
- real-time operational simulation
- parallel system architecture
- explicit XRPL EVM compatibility handling
- zero framework dependency at contract level

---

## Live Links

- **App:** https://isr-network.vercel.app/
- **Contract:** `0xa766e45193e562A934AD2cb1994c8f9007faA897`

---

## Summary

ISR Network demonstrates the ability to:

- architect parallel on-chain systems
- debug non-standard EVM chain behavior
- build deterministic wallet-connected frontends
- handle lifecycle-heavy smart contract design
- translate physical industrial workflows into auditable on-chain state machines

It is not just a mining-themed dApp.  
It is a full-stack operational system model executed on-chain.
