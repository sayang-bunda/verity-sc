// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library DataTypes {
    enum MarketStatus {
        Active,
        Paused,
        Resolved,
        Escalated
    }

    enum MarketOutcome {
        Unresolved,
        Yes,
        No
    }

    enum MarketCategory {
        CryptoPrice,
        Political,
        Sports,
        Other
    }

    struct Market {
        address creator;
        uint64 deadline;
        uint16 feeBps;
        uint8 status;
        uint8 outcome;
        uint8 category;
        uint8 manipulationScore;
        uint128 poolYes;
        uint128 poolNo;
        uint256 totalVolume;
    }

    struct UserPosition {
        uint128 yesShares;
        uint128 noShares;
        uint128 totalBetYes;
        uint128 totalBetNo;
    }

    struct Alert {
        uint256 marketId;
        uint8 score;
        uint64 timestamp;
    }
}
