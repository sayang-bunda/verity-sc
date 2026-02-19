// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";

abstract contract VerityStorage {
    address public immutable USDC;
    address public immutable POSITION_TOKEN;
    uint256 public marketCount;

    mapping(uint256 => DataTypes.Market) internal markets;
    mapping(uint256 => mapping(address => DataTypes.UserPosition))
        internal positions;
    mapping(uint256 => bool) internal seeded;
    mapping(uint256 => mapping(address => bool)) internal claimed;
    mapping(uint256 => uint256) internal accumulatedFees;

    constructor(address _usdc, address _positionToken) {
        if (_usdc == address(0)) revert Errors.ZeroAddress();
        if (_positionToken == address(0)) revert Errors.ZeroAddress();
        USDC = _usdc;
        POSITION_TOKEN = _positionToken;
    }

    function _requireMarketExists(uint256 marketId) internal view {
        if (markets[marketId].creator == address(0))
            revert Errors.MarketNotFound();
    }

    function getMarket(
        uint256 marketId
    ) external view returns (DataTypes.Market memory) {
        return markets[marketId];
    }

    function getPosition(
        uint256 marketId,
        address user
    ) external view returns (DataTypes.UserPosition memory) {
        return positions[marketId][user];
    }

    function isSeeded(uint256 marketId) external view returns (bool) {
        return seeded[marketId];
    }

    function isClaimed(
        uint256 marketId,
        address user
    ) external view returns (bool) {
        return claimed[marketId][user];
    }

    function getAccumulatedFees(
        uint256 marketId
    ) external view returns (uint256) {
        return accumulatedFees[marketId];
    }
}
