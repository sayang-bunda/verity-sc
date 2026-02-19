// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CPMMMath} from "../libraries/CPMMMath.sol";

abstract contract BettingEngine {
    function _calculateBet(uint256 amount, uint256 poolYes, uint256 poolNo, uint16 feeBps, bool isYes)
        internal
        pure
        returns (uint256 shares, uint256 feeAmount, uint256 newPoolYes, uint256 newPoolNo)
    {
        CPMMMath.validateAmount(amount);
        (shares, feeAmount, newPoolYes, newPoolNo) = CPMMMath.calcShares(amount, poolYes, poolNo, feeBps, isYes);
    }

    function _getPrice(uint256 poolYes, uint256 poolNo, bool isYes) internal pure returns (uint256) {
        return CPMMMath.calcPrice(poolYes, poolNo, isYes);
    }

    function _calcMinShares(uint256 expectedShares, uint16 slippageBps) internal pure returns (uint256) {
        return CPMMMath.calcMinShares(expectedShares, slippageBps);
    }
}
