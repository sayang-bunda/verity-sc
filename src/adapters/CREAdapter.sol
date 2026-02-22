// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../libraries/Errors.sol";
import {AccessManager} from "../security/AccessManager.sol";
import {MarketFactory} from "../modules/MarketFactory.sol";
import {RiskEngine} from "../modules/RiskEngine.sol";
import {SettlementEngine} from "../modules/SettlementEngine.sol";

abstract contract CREAdapter is
    AccessManager,
    MarketFactory,
    RiskEngine,
    SettlementEngine
{
    function createMarketFromCre(
        address creator,
        uint64 deadline,
        uint16 feeBps,
        uint8 category,
        string calldata question,
        string calldata resolutionCriteria,
        string calldata dataSources
    ) external onlyCre returns (uint256 marketId) {
        if (!hasRole(ADMIN_ROLE, creator)) revert Errors.Unauthorized();
        marketId = _createMarket(
            creator,
            deadline,
            feeBps,
            category,
            question,
            resolutionCriteria,
            dataSources
        );
    }

    function reportManipulation(
        uint256 marketId,
        uint8 score,
        string calldata reason
    ) external onlyCre {
        _requireMarketExists(marketId);
        _reportManipulation(marketId, score, reason);
    }

    function resolveMarketFromCre(
        uint256 marketId,
        uint8 outcome,
        uint8 confidence
    ) external onlyCre {
        _requireMarketExists(marketId);
        if (block.timestamp < markets[marketId].deadline) {
            revert Errors.DeadlineNotReached();
        }
        _resolveMarket(marketId, outcome, confidence);
    }

    function unpauseMarket(uint256 marketId) external onlyAdmin {
        _requireMarketExists(marketId);
        _unpauseMarket(marketId);
    }
}
