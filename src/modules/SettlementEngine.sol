// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CPMMMath} from "../libraries/CPMMMath.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";

contract SettlementEngine {
    uint8 internal constant CONFIDENCE_THRESHOLD = 90;

    function resolveMarket(uint8 currentStatus, uint8 outcome, uint8 confidence)
        external
        pure
        returns (uint8 newStatus, uint8 newOutcome)
    {
        if (currentStatus == uint8(DataTypes.MarketStatus.Resolved)) {
            revert Errors.MarketAlreadyResolved();
        }
        if (currentStatus == uint8(DataTypes.MarketStatus.Paused)) {
            revert Errors.MarketPaused();
        }
        if (currentStatus != uint8(DataTypes.MarketStatus.Active)) {
            revert Errors.MarketNotActive();
        }
        if (outcome == uint8(DataTypes.MarketOutcome.Unresolved)) {
            revert Errors.InvalidOutcome();
        }
        if (confidence == 0) revert Errors.InvalidConfidence();

        if (confidence >= CONFIDENCE_THRESHOLD) {
            newStatus = uint8(DataTypes.MarketStatus.Resolved);
            newOutcome = outcome;
        } else {
            newStatus = uint8(DataTypes.MarketStatus.Escalated);
            newOutcome = uint8(DataTypes.MarketOutcome.Unresolved);
        }
    }

    function calculatePayout(uint128 yesShares, uint128 noShares, uint128 poolYes, uint128 poolNo, uint8 outcome)
        external
        pure
        returns (uint256 payout)
    {
        if (outcome == uint8(DataTypes.MarketOutcome.Yes)) {
            if (yesShares == 0) return 0;
            if (poolYes == 0) revert Errors.InvalidPool();
            payout = CPMMMath.calcPayout(yesShares, poolYes, poolNo);
        } else if (outcome == uint8(DataTypes.MarketOutcome.No)) {
            if (noShares == 0) return 0;
            if (poolNo == 0) revert Errors.InvalidPool();
            payout = CPMMMath.calcPayout(noShares, poolNo, poolYes);
        } else {
            revert Errors.InvalidOutcome();
        }
    }

    function processRefund(uint128 totalBetYes, uint128 totalBetNo) external pure returns (uint256 refundAmount) {
        if (totalBetYes == 0 && totalBetNo == 0) {
            revert Errors.NoPositionToRefund();
        }
        refundAmount = uint256(totalBetYes) + uint256(totalBetNo);
    }
}
