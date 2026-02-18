// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {AccessManager} from "../security/AccessManager.sol";
import {MarketFactory} from "../modules/MarketFactory.sol";
import {RiskEngine} from "../modules/RiskEngine.sol";

abstract contract CREAdapter is AccessManager, MarketFactory, RiskEngine {
    uint8 internal constant CONFIDENCE_THRESHOLD = 90;

    function createMarketFromCre(
        address creator,
        uint64 deadline,
        uint16 feeBps,
        uint8 category,
        string calldata question,
        string calldata resolutionCriteria,
        string calldata dataSources
    ) external onlyCre returns (uint256 marketId) {
        marketId = _createMarket(creator, deadline, feeBps, category, question, resolutionCriteria, dataSources);
    }

    function reportManipulation(uint256 marketId, uint8 score, string calldata reason) external onlyCre {
        _reportManipulation(marketId, score, reason);
    }

    function resolveMarketFromCre(uint256 marketId, uint8 outcome, uint8 confidence) external onlyCre {
        DataTypes.Market storage m = markets[marketId];

        if (m.status == uint8(DataTypes.MarketStatus.Resolved)) {
            revert Errors.MarketAlreadyResolved();
        }
        if (m.status == uint8(DataTypes.MarketStatus.Paused)) {
            revert Errors.MarketPaused();
        }
        if (m.status != uint8(DataTypes.MarketStatus.Active)) {
            revert Errors.MarketNotActive();
        }
        if (block.timestamp < m.deadline) revert Errors.DeadlineNotReached();
        if (outcome == uint8(DataTypes.MarketOutcome.Unresolved)) {
            revert Errors.InvalidOutcome();
        }
        if (confidence == 0) revert Errors.InvalidConfidence();

        if (confidence >= CONFIDENCE_THRESHOLD) {
            m.status = uint8(DataTypes.MarketStatus.Resolved);
            m.outcome = outcome;
            emit Events.MarketResolved(marketId, outcome);
        } else {
            m.status = uint8(DataTypes.MarketStatus.Escalated);
            emit Events.MarketEscalated(marketId, confidence);
        }
    }

    function unpauseMarket(uint256 marketId) external onlyAdmin {
        _unpauseMarket(marketId);
    }
}
