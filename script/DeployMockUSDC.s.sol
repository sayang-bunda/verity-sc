// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

/**
 * @title DeployMockUSDC
 * @notice Skrip khusus untuk mendeploy MockUSDC saja.
 *
 * Cara menjalankan:
 * forge script script/DeployMockUSDC.s.sol --rpc-url <YOUR_RPC_URL> --broadcast --verify
 */
contract DeployMockUSDC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockUSDC dengan initial supply 1,000,000 USDC (6 decimals)
        // Format: 1,000,000 * 10^6
        uint256 initialSupply = 1_000_000 * 10 ** 6;
        MockUSDC mockUSDC = new MockUSDC(initialSupply);

        console2.log("MockUSDC deployed at:", address(mockUSDC));
        console2.log("Initial Supply minted to deployer:", initialSupply);

        vm.stopBroadcast();
    }
}
