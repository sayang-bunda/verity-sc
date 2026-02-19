// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "./Errors.sol";

library CPMMMath {
    uint256 internal constant MIN_POOL = 1e6;
    uint16 internal constant MAX_FEE_BPS = 1000;
    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant MIN_BET_AMOUNT = 1e5;
    uint256 internal constant MAX_BET_AMOUNT = 1_000_000 * 1e6;
    uint256 internal constant MAX_POOL_RATIO = 1000;

    function calcShares(
        uint256 amount,
        uint256 poolYes,
        uint256 poolNo,
        uint16 feeBps,
        bool isYes
    )
        internal
        pure
        returns (
            uint256 shares,
            uint256 feeAmount,
            uint256 newPoolYes,
            uint256 newPoolNo
        )
    {
        if (poolYes < MIN_POOL) revert Errors.PoolTooLow();
        if (poolNo < MIN_POOL) revert Errors.PoolTooLow();

        feeAmount = calcFee(amount, feeBps);
        uint256 amountAfterFee = amount - feeAmount;
        uint256 k = poolYes * poolNo;

        if (isYes) {
            uint256 newNo = poolNo + amountAfterFee;
            uint256 newYes = k / newNo;
            shares = poolYes - newYes;
            newPoolYes = newYes;
            newPoolNo = newNo;
        } else {
            uint256 newYes = poolYes + amountAfterFee;
            uint256 newNo = k / newYes;
            shares = poolNo - newNo;
            newPoolYes = newYes;
            newPoolNo = newNo;
        }

        if (shares == 0) revert Errors.InsufficientShares();
        if (newPoolYes < MIN_POOL) revert Errors.PoolTooLow();
        if (newPoolNo < MIN_POOL) revert Errors.PoolTooLow();
    }

    function calcPrice(
        uint256 poolYes,
        uint256 poolNo,
        bool isYes
    ) internal pure returns (uint256) {
        uint256 total = poolYes + poolNo;
        if (total == 0) revert Errors.PoolTooLow();
        return
            isYes
                ? (poolNo * BPS_DENOMINATOR) / total
                : (poolYes * BPS_DENOMINATOR) / total;
    }

    function calcFee(
        uint256 amount,
        uint16 feeBps
    ) internal pure returns (uint256) {
        if (feeBps > MAX_FEE_BPS) revert Errors.InvalidFeeBps();
        return (amount * feeBps) / BPS_DENOMINATOR;
    }

    function calcPayout(
        uint256 shares,
        uint256 totalWinningPool,
        uint256 totalLosingPool
    ) internal pure returns (uint256) {
        if (totalWinningPool == 0) revert Errors.InvalidPool();
        return shares + (shares * totalLosingPool) / totalWinningPool;
    }

    function calcMinShares(
        uint256 expectedShares,
        uint16 slippageBps
    ) internal pure returns (uint256) {
        if (slippageBps > BPS_DENOMINATOR) revert Errors.InvalidSlippage();
        return
            expectedShares - (expectedShares * slippageBps) / BPS_DENOMINATOR;
    }

    function validateAmount(uint256 amount) internal pure {
        if (amount < MIN_BET_AMOUNT) revert Errors.AmountTooLow();
        if (amount > MAX_BET_AMOUNT) revert Errors.AmountTooHigh();
    }

    function validateInitialPools(
        uint256 poolYes,
        uint256 poolNo
    ) internal pure {
        if (poolYes < MIN_POOL) revert Errors.PoolTooLow();
        if (poolNo < MIN_POOL) revert Errors.PoolTooLow();
        uint256 ratio = poolYes > poolNo
            ? (poolYes * 100) / poolNo
            : (poolNo * 100) / poolYes;
        if (ratio > MAX_POOL_RATIO) revert Errors.PoolImbalanced();
    }
}
