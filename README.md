# ⛏ ISR Network
<img width="1536" height="1024" alt="ChatGPT Image Mar 31, 2026, 02_48_55 AM" src="https://github.com/user-attachments/assets/b7c450b5-3038-40b1-8f47-d06da2d37147" />

> Real-time In-Situ Recovery uranium extraction control system — built on the **XRPL EVM Sidechain Testnet**.
> A fully deployed Solidity contract powering a live industrial simulation dashboard — no backend, no server, one HTML file.

![XRPL EVM](https://img.shields.io/badge/XRPL%20EVM-Testnet%201449000-8DB600?style=flat-square)
![Solidity](https://img.shields.io/badge/Solidity-0.8.24-A855F7?style=flat-square)
![Contract](https://img.shields.io/badge/Contract-Deployed-00D4FF?style=flat-square)
![Foundry](https://img.shields.io/badge/Foundry-forge%20create-FFB830?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-00FFB8?style=flat-square)

---

## 🔴 Live Demo

**[View Dashboard →](https://isr-network.vercel.app/)**

**Contract on Explorer →** [0xa766e4...faA897](https://explorer.testnet.xrplevm.org/address/0xa766e45193e562A934AD2cb1994c8f9007faA897)

---

## What This Is

ISR Network is a production-grade Web3 control system for a live In-Situ Recovery uranium extraction contract on the XRPL EVM Sidechain.

It is not a simulation — it is a deterministic on-chain execution system modeling real-world uranium extraction processes.

All system state lives on-chain:
- wellfields
- wells (flow, pressure, concentration)
- chemical batches (volume, enrichment, lifecycle stage)
- aquifer integrity + compliance constraints

There is no backend.

All interactions flow directly:

UI (index.html) → ethers.js → XRPL EVM → ISRNetwork.sol

This guarantees:
- every state mutation is a signed transaction
- every read reflects on-chain truth
- every constraint is enforced at the contract level

The frontend is not a dashboard — it is the execution surface of the protocol.

![ScreenRecorderProject45](https://github.com/user-attachments/assets/980fdd8b-12d7-487e-85fd-5dadce03b55f)

---

## Features

### Blockchain
- ✅ Live contract deployed — parallel multi-entity architecture (Wellfield → Well → Batch)
- ✅ Full 8-stage ISR processing pipeline tracked on-chain
- ✅ Multiple wells active simultaneously — each with independent state
- ✅ Circular water recycling loop — processed water returns to injection stage
- ✅ Aquifer compliance enforcement — compromised flag blocks all operations
- ✅ All write functions with 4-step transaction lifecycle (prepare → broadcast → mine → confirm)
- ✅ XRPL EVM gas hardcoded — `eth_estimateGas` and `eth_gasPrice` bypassed entirely
- ✅ 6 read panels to query any on-chain state directly from the UI
- ✅ Real-time event feed via ethers.js provider

### Dashboard
- ✅ Interactive underground cross-section — animated fluid dynamics at ~700ft depth
- ✅ Surface farm scene — animated cows, trees swaying in wind, barn, farmhouse, power lines
- ✅ Global wind system — grass, trees, cow tails all respond to gusts simultaneously
- ✅ Fullscreen underground mode — press **Tab** to enter/exit, click wells to control them
- ✅ 4 toggleable overlays: CHEM heatmap, FLOW vectors, AQUIFER zones, BARRIER integrity
- ✅ Three.js WebGL atomic nucleus with orbiting electrons (60fps background)
- ✅ Wellfield control grid — live well nodes with status, flow rate, pulse animation
- ✅ 8-stage chemical processing pipeline with batch count per stage
- ✅ Environmental compliance panel — aquifer, barriers, radiation, water recycling
- ✅ Uranium yellow-green industrial theme — scanlines, depth glow, beam animations
- ✅ Responsive layout (desktop + mobile)


## 🎬 Full System Execution — End-to-End On-Chain Flow

https://github.com/user-attachments/assets/a36120d9-900c-4ad3-a26b-3626a2de4011

## 🌍 Subsurface Extraction — Live Wellfield Simulation
![ScreenRecorderProject49](https://github.com/user-attachments/assets/379fb590-c348-4f67-85d8-e210e2b1fc3c)

## ⚙️ ISR Processing Pipeline — 8-Stage On-Chain Lifecycle
![ScreenRecorderProject47_2](https://github.com/user-attachments/assets/f721284e-c3ef-46a6-a3e1-523ca95231ef)

## 🖥️ Command Interface — Real-Time Contract State & Controls
![ScreenRecorderProject48](https://github.com/user-attachments/assets/d84e56d2-4d35-4c6d-a20b-648ade643118)

## 📊 On-Chain Query + Execution Panels — Direct Contract Interaction
<img width="1977" height="932" alt="chrome_9ojRYgawva" src="https://github.com/user-attachments/assets/852edc82-0c8b-47dc-900d-88bb62069132" />

## 🔐 Transaction Layer — MetaMask Execution & On-Chain Confirmation
https://github.com/user-attachments/assets/8f03e79b-6c31-48f0-9d9b-b86577ad6a30



---

### Safety & Constraints

- Forward-only batch progression (no rollback)
- Aquifer integrity guard — blocks all operations if compromised
- Hard limits on flow rate and pressure
- Owner-only mutation layer
- No floating point — all values encoded deterministically
- No external dependencies — reduced attack surface

- --


## Contract — `ISRNetwork.sol`

**Deployed:** `0xa766e45193e562A934AD2cb1994c8f9007faA897`
**Network:** XRPL EVM Sidechain Testnet (Chain ID: `1449000`)
**Compiler:** Solidity `0.8.24`

### ISR Processing Stages

| ID | Stage | Description |
|----|-------|-------------|
| 0 | Wellfield Injection | Oxygenated water pumped down ~700ft to dissolve uranium |
| 1 | Resin Reloading | Uranium-rich solution flows through resin bead tanks |
| 2 | Resin Recharge | Salt water strips uranium from resin — resin recycled |
| 3 | Filter Press | Cloths and hoses separate uranium paste from water |
| 4 | Dryer | Zero-emission drying produces dry yellowcake powder |
| 5 | Yellowcake Packaging | Packed in steel drums under NRC/DOT regulations |
| 6 | Transport | Licensed carriers to conversion facility |
| 7 | Conversion Plant | Yellowcake → UF6 gas for isotope enrichment |

### Contract Architecture

```
ISRNetwork
├── Wellfield[]          → geographic cluster (name, location, depth, aquifer)
│   ├── Well[]           → injection or extraction well (flow, pressure, concentration)
│   ├── AquiferZone      → compliance record (barrier integrity, exemption, compromised)
│   └── ChemicalBatch[]  → fluid batch (volume litres, ppm uranium, 8-stage lifecycle)
```

### Write Functions (onlyOwner)

```solidity
createWellfield(string name, string location, uint256 depthFt)
// Creates a new wellfield + initialises its AquiferZone.
// Emits WellfieldCreated.

addWell(uint256 wellfieldId, bool isInjector)
// Adds a well to a wellfield. Must be called BEFORE activateWell.
// isInjector=true for injection, false for extraction.
// Emits WellCreated.

activateWell(uint256 wellId, uint256 flowRate, uint256 pressure)
// Activates a well — sets INJECTING or EXTRACTING status.
// Max: 10,000 L/hr, 5,000 kPa. Blocked if aquifer compromised.
// Emits WellActivated.

deactivateWell(uint256 wellId)
// Sets well to IDLE, zeroes flow and pressure.
// Emits WellDeactivated.

updateWellParameters(uint256 wellId, uint256 flowRate, uint256 pressure, uint256 concentration)
// Updates operating parameters without changing status.
// Emits WellParametersUpdated.

createBatch(uint256 wellfieldId, uint256 wellId, uint256 volumeLitres, uint256 concentrationPpm)
// Creates a chemical solution batch from an extraction well.
// concentrationPpm stored ×10 (integer encoding) — 120 = 12.0 ppm.
// Emits BatchCreated.

advanceBatch(uint256 batchId)
// Advances a batch to the next ISR stage (0→7).
// At stage 7: marks complete, calculates yellowcake kg.
// Emits BatchAdvanced + BatchCompleted at final stage.

recycleBatchWater(uint256 batchId)
// Creates a new batch from a completed batch's water.
// New batch: concentration=0, stage=0, isRecycledWater=true.
// Emits BatchRecycled.

recordAquiferInspection(uint256 wellfieldId, uint8 integrity, bool compromised)
// Records barrier integrity on-chain.
// Below 70: emits AquiferAlert. compromised=true: blocks all operations.

transferOwnership(address newOwner)
// Reverts on zero address. Emits OwnershipTransferred.
```

### Read Functions

```solidity
getNetworkStats()
→ (uint256 totalWellfields, uint256 totalWells, uint256 totalBatches,
   uint256 totalVolume, uint256 totalYellowcake)

getWellfield(uint256 wellfieldId)
→ Wellfield(id, name, location, depthFt, status, wellCount,
            totalBatches, totalVolumeProcessed, createdAt, aquiferSafe)

getWell(uint256 wellId)
→ Well(id, wellfieldId, status, flowRate, pressure, concentration,
       totalExtracted, activatedAt, lastUpdatedAt, isInjector)

getWellfieldWells(uint256 wellfieldId) → uint256[]

getBatch(uint256 batchId)
→ ChemicalBatch(id, wellfieldId, wellId, volumeLitres, concentrationPpm,
                currentStage, recycleCount, isRecycledWater,
                createdBy, createdAt, lastAdvancedAt, complete)

getAquiferZone(uint256 wellfieldId)
→ AquiferZone(wellfieldId, depthTopFt, depthBottomFt,
              barrierIntegrity, exemptionActive, lastInspectedAt, compromised)

wellfieldCount() → uint256
wellCount() → uint256
batchCount() → uint256
owner() → address
```

### Solidity Patterns Used

| Pattern | Implementation |
|---------|---------------|
| Custom errors | `NotOwner`, `InvalidWellfield`, `InvalidWell`, `FlowRateExceeded`, `AquiferCompromised`, `MaxWellsReached` — cheaper than require strings |
| Indexed events | `WellActivated`, `BatchAdvanced`, `AquiferAlert` — all with wellfieldId + wellId indexed |
| Integer encoding | `concentrationPpm` stored ×10 — no floating point on EVM |
| Parallel state | Each Well has independent state — no shared mutex, safe concurrent updates |
| Aquifer guard | `aquiferSafe` modifier blocks activateWell + createBatch when compromised |
| Circular recycling | `recycleBatchWater` creates new batch at stage 0 with `isRecycledWater=true` |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Blockchain | XRPL EVM Sidechain Testnet |
| Smart Contract | Solidity 0.8.24, Foundry |
| Web3 Provider | Ethers.js v5 (CDN) |
| 3D Visualisation | Three.js r128 (CDN) |
| Frontend | Vanilla HTML/CSS/JS, Canvas 2D — zero build step |
| Fonts | Orbitron, Rajdhani (Google Fonts) |
| Hosting | Surge |

---

## Project Structure

```
isr-network/
├── src/
│   └── ISRNetwork.sol         ← Core contract — parallel multi-entity system
├── script/
│   └── Deploy.s.sol           ← Foundry deploy script
├── test/
│   └── ISRNetwork.t.sol       ← Unit + fuzz test suite (25+ cases)
├── frontend/
│   └── index.html             ← Full simulation dashboard SPA
├── foundry.toml               ← Hardcoded gas config for XRPL EVM
├── .env.example               ← Environment template
└── README.md
```

---

## Running Locally

No install required:

```bash
git clone https://github.com/yourusername/isr-network
cd isr-network
open frontend/index.html
# or: python3 -m http.server 8080
```

The simulation runs without a wallet. Connect MetaMask for on-chain interaction.

---

## Build & Test

```bash
# Install forge-std
mkdir -p lib && git clone https://github.com/foundry-rs/forge-std lib/forge-std

# Build
forge build

# Run all tests
forge test -vv

# Fuzz tests
forge test --fuzz-runs 1000 -vv
```

---

## Deploy to XRPL EVM Testnet

> ⚠️ XRPL EVM does not implement `eth_estimateGas` or `eth_gasPrice`.
> Both ethers.js and Foundry call these automatically — the commands below bypass both entirely.

**Step 1 — Hard reset:**
```bash
rm -rf out/ cache/ broadcast/
forge clean
```

**Step 2 — Deploy:**
```bash
export PRIVATE_KEY=your_private_key_here

forge create src/ISRNetwork.sol:ISRNetwork \
  --rpc-url https://rpc.testnet.xrplevm.org \
  --private-key $PRIVATE_KEY \
  --legacy \
  --broadcast
```

**Step 3 — Wire up the frontend:**
```js
// frontend/index.html — top of <script>
var CONTRACT = "0xYOUR_DEPLOYED_ADDRESS_HERE";
```

**Step 4 — Deploy frontend:**
```bash
surge frontend/ isr-command.surge.sh
# or just: surge .   (if index.html is in root)
```

---

## On-Chain Setup Order

After deploying, follow this exact sequence to get a working wellfield:

```bash
export CONTRACT=0xYOUR_ADDRESS
export RPC=https://rpc.testnet.xrplevm.org
export PK=your_private_key
export GAS="--legacy --gas-limit 300000 --gas-price 100000000000"

# 1. Create wellfield (gets ID 0)
cast send $CONTRACT "createWellfield(string,string,uint256)" \
  "Wellfield Alpha" "Texas, USA" 700 --rpc-url $RPC --private-key $PK $GAS

# 2. Add 4 wells (IDs 0-3: inj, ext, inj, ext)
cast send $CONTRACT "addWell(uint256,bool)" 0 true  --rpc-url $RPC --private-key $PK $GAS
cast send $CONTRACT "addWell(uint256,bool)" 0 false --rpc-url $RPC --private-key $PK $GAS
cast send $CONTRACT "addWell(uint256,bool)" 0 true  --rpc-url $RPC --private-key $PK $GAS
cast send $CONTRACT "addWell(uint256,bool)" 0 false --rpc-url $RPC --private-key $PK $GAS

# 3. Activate wells
cast send $CONTRACT "activateWell(uint256,uint256,uint256)" 0 2500 1200 --rpc-url $RPC --private-key $PK $GAS
cast send $CONTRACT "activateWell(uint256,uint256,uint256)" 1 2200 900  --rpc-url $RPC --private-key $PK $GAS
cast send $CONTRACT "activateWell(uint256,uint256,uint256)" 2 1800 1100 --rpc-url $RPC --private-key $PK $GAS
cast send $CONTRACT "activateWell(uint256,uint256,uint256)" 3 2000 850  --rpc-url $RPC --private-key $PK $GAS

# 4. Create a batch from extraction well (ID 1 or 3)
cast send $CONTRACT "createBatch(uint256,uint256,uint256,uint256)" \
  0 1 5000 120 --rpc-url $RPC --private-key $PK $GAS

# 5. Advance batch through stages
cast send $CONTRACT "advanceBatch(uint256)" 0 --rpc-url $RPC --private-key $PK $GAS
```

---

## Connecting MetaMask

| Field | Value |
|-------|-------|
| Network Name | XRPL EVM Testnet |
| RPC URL | `https://rpc.testnet.xrplevm.org` |
| Chain ID | `1449000` |
| Symbol | `XRP` |
| Explorer | `https://explorer.testnet.xrplevm.org` |

Get free testnet XRP: **https://faucet.testnet.xrplevm.org**

---

## XRPL EVM Known Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| MetaMask Internal JSON-RPC error | `eth_estimateGas` called automatically by ethers.js | Frontend hardcodes `gasLimit: 300000, gasPrice: 100 gwei` on every tx |
| Forge simulation fails | `eth_gasPrice` unsupported | Use `forge create` not `forge script` — no simulation phase |
| Tx rejected (wrong type) | EIP-1559 Type 2 not supported | `--legacy` flag required on all forge commands |
| `activateWell` reverts: InvalidWell | Wells not added yet | Must call `addWell()` before `activateWell()` — well IDs start at 0 |
| `createBatch` reverts | AquiferCompromised or well doesn't exist | Check aquifer status, ensure well exists and is active |
| Wrong bytecode deployed | Stale `out/` cache | Always `rm -rf out/ cache/` before redeploy |
| Insufficient fee error | Minimum global fee = 30,000,000,000,000,000 wei | Gas price must be ≥ 100 gwei |

---

## On-Chain Systems Portfolio

| Project | Description | Status |
|---------|-------------|--------|
| **[ZUC Mine Command Center](https://github.com/zrt219/Zuc-Mine-Command-Center)** | On-chain uranium mining operations dashboard — real-time reserve tracking, miner registry, and contract interaction via a fully frontend-driven command interface | ✅ Live |
| **[U235 Fuel Cycle](https://github.com/zrt219/-U235-Fuel-Cycle-)** | Nuclear fuel cycle pipeline — uranium ore to enriched fuel rod, deterministic multi-stage processing with full on-chain traceability | ✅ Live |
| **[ISR Network](https://github.com/zrt219/ISR-Network)** | Intelligence surveillance reconnaissance system — on-chain asset tracking, mission lifecycle state machine, and role-based operator control | ✅ Live |
| **[Dark Matter Farm](https://github.com/zrt219/Dark-Matter-Farm)** | DeFi yield protocol — experimental high-convexity farming system with custom reward mechanics and on-chain state-driven emissions | ✅ Live |
---


---

## License

MIT — see [LICENSE](LICENSE)

