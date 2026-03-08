// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {DebugForwarder} from "../src/mocks/DebugForwarder.sol";

contract DeployDebugForwarder is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        DebugForwarder dbg = new DebugForwarder();
        vm.stopBroadcast();
        console2.log("DebugForwarder:", address(dbg));
        console2.log(
            ">>> Set writeReportReceiver to this address in config.staging.json"
        );
    }
}
