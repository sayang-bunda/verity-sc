// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Verity} from "../src/Verity.sol";
import {PositionToken} from "../src/tokens/PositionToken.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {MockKeystoneForwarder} from "../src/mocks/MockKeystoneForwarder.sol";

/**
 * @title DeployVerity
 * @notice Skrip untuk mendendeploy kontrak Verity dan PositionToken.
 *
 * CRE_ADDRESS: Jika tidak diset, deploy MockKeystoneForwarder (hackathon).
 *               Jika diset, pakai alamat tersebut (production: Keystone Forwarder).
 *
 * Cara menjalankan:
 * forge script script/DeployVerity.s.sol --rpc-url <YOUR_RPC_URL> --broadcast --verify
 */
contract DeployVerity is Script {
    function run() external {
        // Ambil konfigurasi dari environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        address adminAddress = vm.envAddress("ADMIN_ADDRESS");
        address creAddress;
        try vm.envAddress("CRE_ADDRESS") returns (address a) {
            creAddress = a;
        } catch {
            creAddress = address(0);
        }

        vm.startBroadcast(deployerPrivateKey);

        // 1. Setup USDC (Deploy Mock if address not provided)
        address usdc;
        if (usdcAddress == address(0)) {
            console2.log("No USDC_ADDRESS provided, deploying MockUSDC...");
            MockUSDC mock = new MockUSDC(1_000_000 * 10 ** 6);
            usdc = address(mock);
            console2.log("MockUSDC deployed at:", usdc);
        } else {
            usdc = usdcAddress;
            console2.log("Using existing USDC at:", usdc);
        }

        // 2. Deploy PositionToken (ERC1155)
        PositionToken positionToken = new PositionToken();
        console2.log("PositionToken deployed at:", address(positionToken));

        // 3. CRE address: pakai MockKeystoneForwarder jika CRE_ADDRESS tidak diset
        bool useMockForwarder = (creAddress == address(0));
        if (useMockForwarder) {
            MockKeystoneForwarder forwarder = new MockKeystoneForwarder(address(0));
            creAddress = address(forwarder);
            console2.log("MockKeystoneForwarder deployed at:", creAddress);
        }

        // 4. Deploy Verity Core (CRE_ROLE = creAddress)
        Verity verity = new Verity(
            usdc,
            address(positionToken),
            adminAddress,
            creAddress
        );
        console2.log("Verity Core deployed at:", address(verity));

        // 5. Link Verity ke PositionToken
        positionToken.setVerityContract(address(verity));
        console2.log("Verity linked to PositionToken successfully");

        // 6. Jika pakai MockKeystoneForwarder, set Verity address
        if (useMockForwarder) {
            MockKeystoneForwarder(creAddress).setVerity(address(verity));
            console2.log("MockKeystoneForwarder linked to Verity");
        }

        vm.stopBroadcast();

        console2.log("--- Deployment Summary ---");
        console2.log("Network (Chain ID):", block.chainid);
        console2.log("Verity Admin:", adminAddress);
        console2.log("CRE / Keystone Forwarder:", creAddress);
        console2.log("USDC Address:", usdc);
    }
}
