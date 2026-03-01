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
        CryptoPrice, // 0 — resolve via Chainlink Price Feed
        Political, // 1 — resolve via official results / news
        Sports, // 2 — resolve via official sports results
        Other // 3 — resolve via news sources (incl. SOCIAL & EVENT)
    }

    struct Market {
        address creator;
        uint64 deadline;
        uint16 feeBps;
        uint8 status;
        uint8 outcome;
        uint128 poolYes;
        uint128 poolNo;
        uint8 category;
        uint8 manipulationScore;
        uint256 totalVolume;
    }

    struct UserPosition {
        uint128 yesShares;
        uint128 noShares;
        uint128 totalBetYes;
        uint128 totalBetNo;
    }

    struct ResolutionMeta {
        string resolutionCriteria;
        string dataSources;
        int256 targetValue; // Chainlink 8-decimal format (0 if not CryptoPrice)
        address priceFeedAddress; // zero address if not CryptoPrice
    }

    /// @notice Market pending admin review (risk score 31-70 from CRE Workflow 1)
    struct PendingMarket {
        address creator;
        uint64 deadline;
        uint16 feeBps;
        uint8 category;
        uint8 riskScore;
        bool exists;
        string question;
        string resolutionCriteria;
        string dataSources;
    }
}
