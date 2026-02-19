// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../core/libraries/CPMMMath.sol";
import "../core/libraries/DataTypes.sol";
import "../core/libraries/Errors.sol";

contract SettlementEngine {
    uint8 internal constant CONFIDENCE_THRESHOLD = 90;

    function resolveMarket(
        uint8 currentStatus,
        uint8 outcome,
        uint8 confidence
    ) external pure returns (uint8 newStatus, uint8 newOutcome) {
        if (currentStatus == uint8(MarketStatus.Resolved))
            revert MarketAlreadyResolved();
        if (currentStatus == uint8(MarketStatus.Paused)) revert MarketPaused();
        if (currentStatus != uint8(MarketStatus.Active))
            revert MarketNotActive();
        if (outcome == uint8(MarketOutcome.Unresolved)) revert InvalidOutcome();
        if (confidence == 0) revert InvalidConfidence();

        if (confidence >= CONFIDENCE_THRESHOLD) {
            newStatus = uint8(MarketStatus.Resolved);
            newOutcome = outcome;
        } else {
            newStatus = uint8(MarketStatus.Escalated);
            newOutcome = uint8(MarketOutcome.Unresolved);
        }
    }

    function calculatePayout(
        uint128 yesShares,
        uint128 noShares,
        uint128 poolYes,
        uint128 poolNo,
        uint8 outcome
    ) external pure returns (uint256 payout) {
        if (outcome == uint8(MarketOutcome.Yes)) {
            if (yesShares == 0) return 0;
            if (poolYes == 0) revert InvalidPool();
            payout = CPMMMath.calcPayout(yesShares, poolYes, poolNo);
        } else if (outcome == uint8(MarketOutcome.No)) {
            if (noShares == 0) return 0;
            if (poolNo == 0) revert InvalidPool();
            payout = CPMMMath.calcPayout(noShares, poolNo, poolYes);
        } else {
            revert InvalidOutcome();
        }
    }

    function processRefund(
        uint128 totalBetYes,
        uint128 totalBetNo
    ) external pure returns (uint256 refundAmount) {
        if (totalBetYes == 0 && totalBetNo == 0) revert NoPositionToRefund();
        refundAmount = uint256(totalBetYes) + uint256(totalBetNo);
    }
}
