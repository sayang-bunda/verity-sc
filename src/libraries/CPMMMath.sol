// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "./Errors.sol";

library CPMMMath {
    uint256 internal constant MIN_POOL = 1e6;
    uint16 internal constant MAX_FEE_BPS = 1000;
    uint256 internal constant BPS_DENOMINATOR = 10000;
    uint256 internal constant MIN_BET_AMOUNT = 1e5;
    uint256 internal constant MAX_BET_AMOUNT = 1_000_000 * 1e6;
    uint256 internal constant MAX_POOL_RATIO = 1000;

    function calcShares(uint256 amount, uint256 poolYes, uint256 poolNo, uint16 feeBps, bool isYes)
        internal
        pure
        returns (uint256 shares, uint256 feeAmount, uint256 newPoolYes, uint256 newPoolNo)
    {
        if (poolYes < MIN_POOL) revert Errors.PoolTooLow();
        if (poolNo < MIN_POOL) revert Errors.PoolTooLow();

        feeAmount = calcFee(amount, feeBps);
        uint256 amountAfterFee = amount - feeAmount;
        uint256 k = poolYes * poolNo;

        if (isYes) {
            uint256 newPoolNoTemp = poolNo + amountAfterFee;
            uint256 newPoolYesTemp = k / newPoolNoTemp;

            shares = poolYes - newPoolYesTemp;
            newPoolYes = newPoolYesTemp;
            newPoolNo = newPoolNoTemp;
        } else {
            uint256 newPoolYesTemp = poolYes + amountAfterFee;
            uint256 newPoolNoTemp = k / newPoolYesTemp;

            shares = poolNo - newPoolNoTemp;
            newPoolYes = newPoolYesTemp;
            newPoolNo = newPoolNoTemp;
        }

        if (shares == 0) revert Errors.InsufficientShares();
        if (newPoolYes < MIN_POOL) revert Errors.PoolTooLow();
        if (newPoolNo < MIN_POOL) revert Errors.PoolTooLow();
    }

    function calcPrice(uint256 poolYes, uint256 poolNo, bool isYes) internal pure returns (uint256 price) {
        uint256 totalPool = poolYes + poolNo;
        if (totalPool == 0) revert Errors.PoolTooLow();

        if (isYes) {
            price = (poolNo * BPS_DENOMINATOR) / totalPool;
        } else {
            price = (poolYes * BPS_DENOMINATOR) / totalPool;
        }
    }

    function calcFee(uint256 amount, uint16 feeBps) internal pure returns (uint256 feeAmount) {
        if (feeBps > MAX_FEE_BPS) revert Errors.InvalidFeeBps();
        feeAmount = (amount * feeBps) / BPS_DENOMINATOR;
    }

    function validateAmount(uint256 amount) internal pure {
        if (amount < MIN_BET_AMOUNT) revert Errors.AmountTooLow();
        if (amount > MAX_BET_AMOUNT) revert Errors.AmountTooHigh();
    }

    function validateFeeBps(uint16 feeBps) internal pure {
        if (feeBps > MAX_FEE_BPS) revert Errors.InvalidFeeBps();
    }

    function validateInitialPools(uint256 poolYes, uint256 poolNo) internal pure {
        if (poolYes < MIN_POOL) revert Errors.PoolTooLow();
        if (poolNo < MIN_POOL) revert Errors.PoolTooLow();
        uint256 ratio = poolYes > poolNo ? (poolYes * 100) / poolNo : (poolNo * 100) / poolYes;
        if (ratio > MAX_POOL_RATIO) revert Errors.PoolImbalanced();
    }

    function calcMinShares(uint256 expectedShares, uint16 slippageBps) internal pure returns (uint256 minShares) {
        if (slippageBps > BPS_DENOMINATOR) revert Errors.InvalidSlippage();
        minShares = expectedShares - ((expectedShares * slippageBps) / BPS_DENOMINATOR);
    }

    function calcPayout(uint256 shares, uint256 totalWinningPool, uint256 totalLosingPool)
        internal
        pure
        returns (uint256 payout)
    {
        if (totalWinningPool == 0) revert Errors.InvalidPool();
        uint256 shareOfLosingPool = (shares * totalLosingPool) / totalWinningPool;
        payout = shares + shareOfLosingPool;
    }
}
