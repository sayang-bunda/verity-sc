// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMockUSDC {
    function mint(address to, uint256 amount) external;
}

interface IVerity {
    function placeBet(
        uint256 marketId,
        uint256 amount,
        bool isYes,
        uint256 minShares
    ) external;
}

/**
 * @title PlaceSuspiciousBet
 * @notice Mint a large amount of MockUSDC and place a suspicious large bet.
 *         The large bet amount should trigger CRE-2 to score > 30 (MONITOR/FLAG).
 *
 * Usage:
 *   source .env && forge script script/PlaceSuspiciousBet.s.sol \
 *     --rpc-url https://sepolia.base.org --broadcast
 */
contract PlaceSuspiciousBet is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address verity = vm.envAddress("VERITY_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address wallet = vm.addr(pk);

        // ── Config ──
        uint256 marketId = 0;
        uint256 betAmount = 50e6; // 50 USDC — large relative to ~200 USDC pool
        bool isYes = true;
        uint256 minShares = 0;

        vm.startBroadcast(pk);

        // 1. Mint 500k USDC (MockUSDC has no owner restriction, max 1M per call)
        IMockUSDC(usdc).mint(wallet, betAmount);
        console2.log("Minted USDC :", betAmount);

        // 2. Approve Verity to spend
        IERC20(usdc).approve(verity, betAmount);

        // 3. Place the suspicious large bet
        IVerity(verity).placeBet(marketId, betAmount, isYes, minShares);

        vm.stopBroadcast();

        console2.log("--- Suspicious Bet Placed ---");
        console2.log("Market ID :", marketId);
        console2.log("Amount    :", betAmount, "(50 USDC)");
        console2.log("Side      : YES");
        console2.log("");
        console2.log(
            ">>> Use the TX hash of placeBet as input for CRE-2 simulation"
        );
    }
}
