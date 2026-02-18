// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/libraries/CPMMMath.sol";

contract BettingEngine {
    function calculateBet(
        uint256 amount,
        uint256 poolYes,
        uint256 poolNo,
        uint16 feeBps,
        bool isYes
    )
        public
        pure
        returns (
            uint256 shares,
            uint256 feeAmount,
            uint256 newPoolYes,
            uint256 newPoolNo
        )
    {
        CPMMMath.validateAmount(amount);
        CPMMMath.validateFeeBps(feeBps);

        (shares, feeAmount, newPoolYes, newPoolNo) = CPMMMath.calcShares(
            amount,
            poolYes,
            poolNo,
            feeBps,
            isYes
        );
    }

    function getPrice(
        uint256 poolYes,
        uint256 poolNo,
        bool isYes
    ) public pure returns (uint256 price) {
        return CPMMMath.calcPrice(poolYes, poolNo, isYes);
    }

    function getMinShares(
        uint256 expectedShares,
        uint16 slippageBps
    ) public pure returns (uint256 minShares) {
        return CPMMMath.calcMinShares(expectedShares, slippageBps);
    }
}
