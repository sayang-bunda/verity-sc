// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {CPMMMath} from "../libraries/CPMMMath.sol";
import {VerityStorage} from "../core/VerityStorage.sol";

abstract contract SettlementEngine is VerityStorage {
    uint8 internal constant CONFIDENCE_THRESHOLD = 90;

    /// @dev reason and evidenceUrls can be empty for backward compat
    function _resolveMarket(
        uint256 marketId,
        uint8 outcome,
        uint8 confidence,
        string memory reason,
        string[] memory evidenceUrls
    ) internal {
        DataTypes.Market storage m = markets[marketId];

        if (m.status == uint8(DataTypes.MarketStatus.Resolved)) revert Errors.MarketAlreadyResolved();
        if (m.status == uint8(DataTypes.MarketStatus.Paused)) revert Errors.MarketPaused();
        if (m.status != uint8(DataTypes.MarketStatus.Active) && m.status != uint8(DataTypes.MarketStatus.Escalated)) {
            revert Errors.MarketNotActive();
        }
        if (outcome == uint8(DataTypes.MarketOutcome.Unresolved)) revert Errors.InvalidOutcome();
        if (confidence == 0) revert Errors.InvalidConfidence();

        if (confidence >= CONFIDENCE_THRESHOLD) {
            m.status = uint8(DataTypes.MarketStatus.Resolved);
            m.outcome = outcome;

            if (bytes(reason).length > 0 || evidenceUrls.length > 0) {
                resolutionReasons[marketId] = reason;
                resolutionEvidenceUrls[marketId] = evidenceUrls;
                emit Events.MarketResolvedWithEvidence(marketId, outcome, confidence, reason, evidenceUrls);
            }
            emit Events.MarketResolved(marketId, outcome, confidence);

            // Refund creator deposit (Feature 1)
            uint256 deposit = creatorDeposits[marketId];
            if (deposit > 0) {
                creatorDeposits[marketId] = 0;
                _refundCreatorDeposit(marketId, m.creator, deposit);
            }
        } else {
            m.status = uint8(DataTypes.MarketStatus.Escalated);
            m.outcome = uint8(DataTypes.MarketOutcome.Unresolved);
            emit Events.MarketEscalated(marketId, confidence);
        }
    }

    /// @dev Override in Verity to perform USDC transfer
    function _refundCreatorDeposit(uint256 marketId, address creator, uint256 amount) internal virtual;

    function _calculatePayout(uint128 yesShares, uint128 noShares, uint128 poolYes, uint128 poolNo, uint8 outcome)
        internal
        pure
        returns (uint256)
    {
        if (outcome == uint8(DataTypes.MarketOutcome.Yes)) {
            if (yesShares == 0) return 0;
            return CPMMMath.calcPayout(yesShares, poolYes, poolNo);
        } else if (outcome == uint8(DataTypes.MarketOutcome.No)) {
            if (noShares == 0) return 0;
            return CPMMMath.calcPayout(noShares, poolNo, poolYes);
        }
        revert Errors.InvalidOutcome();
    }

    function _calculateRefund(uint128 totalBetYes, uint128 totalBetNo) internal pure returns (uint256) {
        if (totalBetYes == 0 && totalBetNo == 0) revert Errors.NoPositionToRefund();
        return uint256(totalBetYes) + uint256(totalBetNo);
    }
}
