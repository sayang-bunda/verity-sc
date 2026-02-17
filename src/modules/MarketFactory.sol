// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {SafeMarketStorage} from "../core/SafeMarketStorage.sol";

abstract contract MarketFactory is SafeMarketStorage {
    uint16 public constant MAX_FEE_BPS = 1000;

    function _createMarket(
        address creator,
        uint64 deadline,
        uint16 feeBps,
        uint8 category,
        string calldata question,
        string calldata resolutionCriteria,
        string calldata dataSources
    ) internal returns (uint256 marketId) {
        if (deadline <= block.timestamp) revert Errors.DeadlineAlreadyPassed();
        if (feeBps > MAX_FEE_BPS) revert Errors.InvalidFeeBps();

        marketId = marketCount++;

        DataTypes.Market storage m = markets[marketId];
        m.creator = creator;
        m.deadline = deadline;
        m.feeBps = feeBps;
        m.status = uint8(DataTypes.MarketStatus.Active);
        m.outcome = uint8(DataTypes.MarketOutcome.Unresolved);
        m.category = category;

        emit Events.MarketCreated(marketId, creator, question, resolutionCriteria, dataSources, deadline, feeBps);
    }
}
