// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";

abstract contract SafeMarketStorage {
    address public usdc;
    address public positionToken;

    uint256 public marketCount;

    mapping(uint256 => DataTypes.Market) internal markets;
    mapping(uint256 => mapping(address => DataTypes.UserPosition)) internal positions;
    mapping(uint256 => bool) internal seeded;
    mapping(uint256 => mapping(address => bool)) internal claimed;
    mapping(uint256 => uint256) internal accumulatedFees;

    function getMarket(uint256 marketId) external view returns (DataTypes.Market memory) {
        return markets[marketId];
    }

    function getPosition(uint256 marketId, address user) external view returns (DataTypes.UserPosition memory) {
        return positions[marketId][user];
    }

    function isSeeded(uint256 marketId) external view returns (bool) {
        return seeded[marketId];
    }

    function isClaimed(uint256 marketId, address user) external view returns (bool) {
        return claimed[marketId][user];
    }

    function getAccumulatedFees(uint256 marketId) external view returns (uint256) {
        return accumulatedFees[marketId];
    }
}

