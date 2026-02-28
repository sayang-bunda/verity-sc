// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {VerityStorage} from "../core/VerityStorage.sol";

abstract contract MarketFactory is VerityStorage {
    uint16 public constant MAX_FEE_BPS = 1000;

    function _createMarket(
        address creator,
        uint64 deadline,
        uint16 feeBps,
        uint8 category,
        string memory question,
        string memory resolutionCriteria,
        string memory dataSources,
        int256 targetValue,
        address priceFeedAddress
    ) internal returns (uint256 marketId) {
        if (creator == address(0)) revert Errors.ZeroAddress();
        if (deadline <= block.timestamp) revert Errors.DeadlineAlreadyPassed();
        if (feeBps > MAX_FEE_BPS) revert Errors.InvalidFeeBps();
        if (category > uint8(type(DataTypes.MarketCategory).max)) {
            revert Errors.InvalidCategory();
        }

        marketId = marketCount++;

        DataTypes.Market storage m = markets[marketId];
        m.creator = creator;
        m.deadline = deadline;
        m.feeBps = feeBps;
        m.status = uint8(DataTypes.MarketStatus.Active);
        m.outcome = uint8(DataTypes.MarketOutcome.Unresolved);
        m.category = category;

        marketQuestions[marketId] = question;

        DataTypes.ResolutionMeta storage r = resolutionMeta[marketId];
        r.resolutionCriteria = resolutionCriteria;
        r.dataSources = dataSources;
        r.targetValue = targetValue;
        r.priceFeedAddress = priceFeedAddress;

        emit Events.MarketCreated(
            marketId, creator, category, deadline, feeBps, question, resolutionCriteria, dataSources
        );
    }
}
