// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IVerity {
    function requestSettlement(uint256 marketId) external;
}

/**
 * @title RequestSettlement
 * @notice Request settlement to trigger CRE-3.
 *
 * Usage:
 *   source .env && forge script script/RequestSettlement.s.sol \
 *     --rpc-url https://sepolia.base.org --broadcast
 */
contract RequestSettlement is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address verity = vm.envAddress("VERITY_ADDRESS");

        // ── Config ──
        uint256 marketId = 0;

        vm.startBroadcast(pk);
        IVerity(verity).requestSettlement(marketId);
        vm.stopBroadcast();

        console2.log("--- Settlement Requested ---");
        console2.log("Market ID :", marketId);
        console2.log("");
        console2.log(">>> Use the TX hash above as input for CRE-3 simulation");
    }
}
