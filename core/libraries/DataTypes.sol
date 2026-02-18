// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

enum MarketStatus {
    Active,
    Paused,
    Resolved,
    Escalated,
    Cancelled
}

enum MarketOutcome {
    Unresolved,
    Yes,
    No
}

enum MarketCategory {
    Crypto,
    Sports,
    Politics,
    Entertainment,
    Other
}

struct Market {
    address creator;
    uint128 poolYes;
    uint128 poolNo;
    uint64 deadline;
    uint16 feeBps;
    uint8 status; // MarketStatus
    uint8 outcome; // MarketOutcome
    uint8 category; // MarketCategory
    uint8 manipulationScore;
    uint256 totalVolume;
}

struct UserPosition {
    uint128 yesShares;
    uint128 noShares;
    uint128 totalBetYes;
    uint128 totalBetNo;
}
