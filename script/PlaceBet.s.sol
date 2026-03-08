// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVerity {
    function placeBet(
        uint256 marketId,
        uint256 amount,
        bool isYes,
        uint256 minShares
    ) external;
}

/**
 * @title PlaceBet
 * @notice Place a bet on a Verity prediction market.
 *         Emits BetPlaced event that CRE-2 listens for.
 *
 * Usage:
 *   source .env && forge script script/PlaceBet.s.sol \
 *     --rpc-url https://sepolia.base.org --broadcast
 */
contract PlaceBet is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address verity = vm.envAddress("VERITY_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");

        // ── Config ──
        uint256 marketId = 0; // Market created by CRE-1
        uint256 betAmount = 10e6; // 10 USDC (6 decimals)
        bool isYes = true; // Bet YES
        uint256 minShares = 0; // No slippage protection for testing

        vm.startBroadcast(pk);

        // Approve USDC spending
        IERC20(usdc).approve(verity, betAmount);

        // Place the bet (emits BetPlaced event)
        IVerity(verity).placeBet(marketId, betAmount, isYes, minShares);

        vm.stopBroadcast();

        console2.log("--- Bet Placed ---");
        console2.log("Market ID :", marketId);
        console2.log("Amount    :", betAmount);
        console2.log("Side      : YES");
        console2.log("");
        console2.log(">>> Use the TX hash above as input for CRE-2 simulation");
    }
}
