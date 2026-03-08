// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {
    IAccessControl
} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {MockForwarderV2} from "../src/mocks/MockForwarderV2.sol";

/**
 * @title DeployMockForwarderV2
 * @notice Deplyoy MockForwarderV2 + grant CRE_ROLE to it in Verity
 *
 * Execution:
 *   forge script script/DeployMockForwarderV2.s.sol \
 *     --rpc-url https://sepolia.base.org \
 *     --broadcast \
 *     --verify \
 *     --etherscan-api-key $BASESCAN_API_KEY
 *
 * Req env vars:
 *   PRIVATE_KEY    — deployment and admin wallet
 *   VERITY_ADDRESS — currently deployed Verity
 */
contract DeployMockForwarderV2 is Script {
    bytes32 constant CRE_ROLE = keccak256("CRE_ROLE");

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address verityAddress = vm.envAddress("VERITY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the new MockForwarderV2
        MockForwarderV2 forwarder = new MockForwarderV2();

        // 2. Grant CRE_ROLE directly to the new MockForwarderV2
        IAccessControl(verityAddress).grantRole(CRE_ROLE, address(forwarder));

        vm.stopBroadcast();

        console2.log("--- MockForwarderV2 Deployment ---");
        console2.log("Verity              :", verityAddress);
        console2.log("MockForwarderV2     :", address(forwarder));
        console2.log("CRE_ROLE granted    : OK");
        console2.log("");
        console2.log(
            ">>> Make sure to update project.yaml experimental-chains setting with this MockForwarderV2 address:"
        );
        console2.log('    "forwarder": "%s"', address(forwarder));
    }
}
