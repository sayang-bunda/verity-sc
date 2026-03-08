// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {KeystoneOnReportAdapter} from "../src/mocks/KeystoneOnReportAdapter.sol";

/**
 * @title DeployKeystoneAdapter
 * @notice Deploy KeystoneOnReportAdapter + grant CRE_ROLE ke adapter di Verity.
 *
 * Flow setelah deploy:
 *   CRE SDK → Real Keystone Forwarder → adapter.onReport() → Verity.onReport()
 *
 * Cara menjalankan:
 *   forge script script/DeployKeystoneAdapter.s.sol \
 *     --rpc-url https://sepolia.base.org \
 *     --broadcast \
 *     --verify \
 *     --etherscan-api-key $BASESCAN_API_KEY
 *
 * Env vars yang dibutuhkan:
 *   PRIVATE_KEY    — admin private key (harus punya ADMIN_ROLE di Verity)
 *   VERITY_ADDRESS — alamat Verity yang sudah deployed
 */
contract DeployKeystoneAdapter is Script {
    bytes32 constant CRE_ROLE = keccak256("CRE_ROLE");

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address verityAddress = vm.envAddress("VERITY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy adapter pointing langsung ke Verity
        KeystoneOnReportAdapter adapter = new KeystoneOnReportAdapter(verityAddress);

        // 2. Grant CRE_ROLE ke adapter di Verity
        IAccessControl(verityAddress).grantRole(CRE_ROLE, address(adapter));

        vm.stopBroadcast();

        console2.log("--- KeystoneOnReportAdapter Deployment ---");
        console2.log("Verity                 :", verityAddress);
        console2.log("KeystoneOnReportAdapter:", address(adapter));
        console2.log("CRE_ROLE granted        : OK");
        console2.log("");
        console2.log(">>> Update writeReportReceiver di semua config.staging.json:");
        console2.log('    "writeReportReceiver": "%s"', address(adapter));
    }
}
