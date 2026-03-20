// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ISRNetwork} from "../src/ISRNetwork.sol";

contract ISRNetworkTest is Test {
    ISRNetwork public isr;
    address    public owner   = address(this);
    address    public notOwner = makeAddr("notOwner");

    function setUp() public {
        isr = new ISRNetwork();
        // Create default wellfield + wells for most tests
        isr.createWellfield("Alpha", "Texas", 700);
        isr.addWell(0, true);  // well 0 injector
        isr.addWell(0, false); // well 1 extractor
    }

    /* ── Deploy ── */
    function test_DeployOwner() public view { assertEq(isr.owner(), owner); }
    function test_DeployCounts() public view { assertEq(isr.wellfieldCount(), 1); assertEq(isr.wellCount(), 2); }

    /* ── Wellfield ── */
    function test_CreateWellfield() public {
        isr.createWellfield("Beta", "Wyoming", 650);
        assertEq(isr.wellfieldCount(), 2);
        ISRNetwork.Wellfield memory wf = isr.getWellfield(1);
        assertEq(wf.depthFt, 650);
        assertTrue(wf.aquiferSafe);
    }

    function test_CreateWellfield_NotOwner() public {
        vm.prank(notOwner);
        vm.expectRevert(ISRNetwork.NotOwner.selector);
        isr.createWellfield("Beta", "WY", 700);
    }

    function test_SetWellfieldStatus() public {
        isr.setWellfieldStatus(0, ISRNetwork.WellfieldStatus.ACTIVE);
        ISRNetwork.Wellfield memory wf = isr.getWellfield(0);
        assertEq(uint8(wf.status), uint8(ISRNetwork.WellfieldStatus.ACTIVE));
    }

    /* ── Wells ── */
    function test_AddWell() public {
        isr.addWell(0, true);
        assertEq(isr.wellCount(), 3);
    }

    function test_AddWell_MaxReached() public {
        for (uint i = 0; i < 14; i++) isr.addWell(0, i%2==0);
        vm.expectRevert(abi.encodeWithSelector(ISRNetwork.MaxWellsReached.selector, 0));
        isr.addWell(0, true);
    }

    function test_ActivateWell() public {
        vm.expectEmit(true,true,false,true);
        emit ISRNetwork.WellActivated(0, 0, 2500, 1200, block.timestamp);
        isr.activateWell(0, 2500, 1200);
        ISRNetwork.Well memory w = isr.getWell(0);
        assertEq(uint8(w.status), uint8(ISRNetwork.WellStatus.INJECTING));
        assertEq(w.flowRate, 2500);
    }

    function test_ActivateWell_FlowRateExceeded() public {
        vm.expectRevert(abi.encodeWithSelector(ISRNetwork.FlowRateExceeded.selector, 99999, 10000));
        isr.activateWell(0, 99999, 1000);
    }

    function test_ActivateWell_PressureExceeded() public {
        vm.expectRevert(abi.encodeWithSelector(ISRNetwork.PressureExceeded.selector, 9999, 5000));
        isr.activateWell(0, 2000, 9999);
    }

    function test_ActivateWell_AlreadyActive() public {
        isr.activateWell(0, 2500, 1200);
        vm.expectRevert(abi.encodeWithSelector(ISRNetwork.WellAlreadyActive.selector, 0, 0));
        isr.activateWell(0, 2000, 1000);
    }

    function test_DeactivateWell() public {
        isr.activateWell(0, 2500, 1200);
        isr.deactivateWell(0);
        ISRNetwork.Well memory w = isr.getWell(0);
        assertEq(uint8(w.status), uint8(ISRNetwork.WellStatus.IDLE));
        assertEq(w.flowRate, 0);
    }

    function test_UpdateWellParameters() public {
        isr.activateWell(0, 2500, 1200);
        isr.updateWellParameters(0, 3000, 1500, 85);
        ISRNetwork.Well memory w = isr.getWell(0);
        assertEq(w.flowRate, 3000);
        assertEq(w.pressure, 1500);
        assertEq(w.concentration, 85);
    }

    /* ── Batches ── */
    function test_CreateBatch() public {
        isr.activateWell(1, 2000, 900);
        vm.expectEmit(true,true,true,true);
        emit ISRNetwork.BatchCreated(0, 0, 1, 5000, 120, owner);
        isr.createBatch(0, 1, 5000, 120);
        assertEq(isr.batchCount(), 1);
    }

    function test_CreateBatch_ZeroVolume() public {
        vm.expectRevert(ISRNetwork.ZeroVolume.selector);
        isr.createBatch(0, 1, 0, 100);
    }

    function test_AdvanceBatch_FullPipeline() public {
        isr.activateWell(1, 2000, 900);
        isr.createBatch(0, 1, 5000, 120);
        for (uint i = 0; i < 7; i++) isr.advanceBatch(0);
        ISRNetwork.ChemicalBatch memory b = isr.getBatch(0);
        assertTrue(b.complete);
        assertEq(b.currentStage, 7);
    }

    function test_AdvanceBatch_AlreadyComplete() public {
        isr.activateWell(1, 2000, 900);
        isr.createBatch(0, 1, 5000, 120);
        for (uint i = 0; i < 7; i++) isr.advanceBatch(0);
        vm.expectRevert(abi.encodeWithSelector(ISRNetwork.BatchAlreadyComplete.selector, 0));
        isr.advanceBatch(0);
    }

    function test_RecycleBatchWater() public {
        isr.activateWell(1, 2000, 900);
        isr.createBatch(0, 1, 5000, 120);
        for (uint i = 0; i < 7; i++) isr.advanceBatch(0);
        isr.recycleBatchWater(0);
        assertEq(isr.batchCount(), 2);
        ISRNetwork.ChemicalBatch memory recycled = isr.getBatch(1);
        assertTrue(recycled.isRecycledWater);
        assertEq(recycled.concentrationPpm, 0); // stripped
        assertEq(recycled.currentStage, 0);     // back to injection
        assertEq(recycled.recycleCount, 1);
    }

    /* ── Aquifer ── */
    function test_AquiferInspection_OK() public {
        isr.recordAquiferInspection(0, 95, false);
        ISRNetwork.AquiferZone memory z = isr.getAquiferZone(0);
        assertEq(z.barrierIntegrity, 95);
        assertFalse(z.compromised);
    }

    function test_AquiferInspection_Compromised() public {
        vm.expectEmit(true,false,false,true);
        emit ISRNetwork.AquiferAlert(0, 30, true, block.timestamp);
        isr.recordAquiferInspection(0, 30, true);
    }

    function test_AquiferCompromised_BlocksWellActivation() public {
        isr.recordAquiferInspection(0, 30, true);
        vm.expectRevert(abi.encodeWithSelector(ISRNetwork.AquiferCompromised.selector, 0));
        isr.activateWell(0, 2000, 1000);
    }

    function test_AquiferCompromised_BlocksBatchCreation() public {
        isr.activateWell(1, 2000, 900);
        isr.recordAquiferInspection(0, 30, true);
        vm.expectRevert(abi.encodeWithSelector(ISRNetwork.AquiferCompromised.selector, 0));
        isr.createBatch(0, 1, 5000, 100);
    }

    /* ── Concurrent operations ── */
    function test_MultipleWellsActive() public {
        isr.activateWell(0, 2500, 1200);
        isr.activateWell(1, 2000, 900);
        ISRNetwork.Well memory w0 = isr.getWell(0);
        ISRNetwork.Well memory w1 = isr.getWell(1);
        assertEq(uint8(w0.status), uint8(ISRNetwork.WellStatus.INJECTING));
        assertEq(uint8(w1.status), uint8(ISRNetwork.WellStatus.EXTRACTING));
    }

    function test_MultipleBatchesConcurrent() public {
        isr.activateWell(1, 2000, 900);
        isr.createBatch(0, 1, 5000, 120);
        isr.createBatch(0, 1, 3000, 85);
        isr.advanceBatch(0); // batch 0 → stage 1
        // batch 1 still at stage 0 — independent
        assertEq(isr.getBatch(0).currentStage, 1);
        assertEq(isr.getBatch(1).currentStage, 0);
    }

    /* ── Network Stats ── */
    function test_NetworkStats() public {
        isr.activateWell(1, 2000, 900);
        isr.createBatch(0, 1, 5000, 120);
        (uint256 wfs, uint256 wells, uint256 batches, uint256 vol,) = isr.getNetworkStats();
        assertEq(wfs, 1);
        assertEq(wells, 2);
        assertEq(batches, 1);
        assertEq(vol, 5000);
    }

    /* ── Fuzz ── */
    function testFuzz_ActivateWell_ValidParams(uint256 fr, uint256 pr) public {
        fr = bound(fr, 1, 10000);
        pr = bound(pr, 1, 5000);
        isr.activateWell(0, fr, pr);
        assertEq(isr.getWell(0).flowRate, fr);
    }

    function testFuzz_CreateBatch_ValidVolume(uint256 vol) public {
        vol = bound(vol, 1, 1_000_000);
        isr.createBatch(0, 1, vol, 100);
        assertEq(isr.getBatch(0).volumeLitres, vol);
    }
}
