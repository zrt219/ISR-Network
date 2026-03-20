// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ISRNetwork} from "../src/ISRNetwork.sol";

/**
 * @title  Deploy
 * @notice Deploys ISRNetwork to XRPL EVM Sidechain testnet.
 *
 * DEPLOY COMMAND:
 *   forge create src/ISRNetwork.sol:ISRNetwork \
 *     --rpc-url https://rpc.testnet.xrplevm.org \
 *     --private-key $PRIVATE_KEY \
 *     --legacy \
 *     --broadcast
 */
contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        console2.log("=== ISRNetwork Deployment ===");
        console2.log("Deployer :", deployer);
        console2.log("Chain ID :", block.chainid);

        vm.startBroadcast(deployerKey);

        ISRNetwork isr = new ISRNetwork();

        // Seed: create first wellfield
        isr.createWellfield("Wellfield Alpha", "Texas Plains, USA", 700);

        // Add 2 injection + 2 extraction wells
        isr.addWell(0, true);   // well 0: injector
        isr.addWell(0, false);  // well 1: extractor
        isr.addWell(0, true);   // well 2: injector
        isr.addWell(0, false);  // well 3: extractor

        // Activate wells
        isr.activateWell(0, 2500, 1200); // 2500 L/hr, 1200 kPa
        isr.activateWell(1, 2200, 900);
        isr.activateWell(2, 1800, 1100);
        isr.activateWell(3, 2000, 850);

        // Set aquifer exemption
        isr.setAquiferExemption(0, true);

        vm.stopBroadcast();

        console2.log("ISRNetwork:", address(isr));
        console2.log("Owner     :", isr.owner());
        console2.log("=================================");

        require(address(isr) != address(0), "Deploy: zero address");
        require(isr.owner() == deployer,    "Deploy: owner mismatch");
    }
}
