// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {SafeMarketStorage} from "../core/SafeMarketStorage.sol";

abstract contract RiskEngine is SafeMarketStorage {
    uint8 public constant MANIPULATION_THRESHOLD = 70;

    function _reportManipulation(
        uint256 marketId,
        uint8 score,
        string calldata reason
    ) internal {
        DataTypes.Market storage m = markets[marketId];
        if (m.status != uint8(DataTypes.MarketStatus.Active))
            revert Errors.MarketNotActive();

        m.manipulationScore = score;

        emit Events.ManipulationAlert(marketId, score, reason);

        if (score >= MANIPULATION_THRESHOLD) {
            m.status = uint8(DataTypes.MarketStatus.Paused);
            emit Events.MarketPaused(marketId);
        }
    }

    function _unpauseMarket(uint256 marketId) internal {
        DataTypes.Market storage m = markets[marketId];
        if (m.status != uint8(DataTypes.MarketStatus.Paused))
            revert Errors.MarketNotActive();

        m.status = uint8(DataTypes.MarketStatus.Active);
        m.manipulationScore = 0;

        emit Events.MarketUnpaused(marketId);
    }
}
