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
        Event, // 1 — resolve via news/official sources
        Social, // 2 — resolve via social metrics/news
        Other // 3 — resolve via general news sources
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

    /// @notice Anti-spam: $5 escrow when user proposes a market. Refunded if rejected or when market resolves.
    enum ProposalStatus {
        Pending,
        Approved,
        Rejected
    }

    struct MarketProposal {
        address creator;
        uint256 amount;
        string payloadJSON;
        ProposalStatus status;
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

    /// @notice Recorded on-chain when a user submits a market creation request (Tx 1).
    /// @dev CRE-1 workflow picks up MarketCreationRequested event, runs BFT consensus,
    ///      then calls onReport() to create the actual market (Tx 2).
    struct MarketRequest {
        address creator;
        string question;
        uint8 category;
        uint64 deadline;
        uint16 feeBps;
        uint256 timestamp;
    }

    /// @notice Records a high-risk market rejection on-chain (risk score 71-100)
    /// @dev Written by CRE via ACTION_REJECT_MARKET — immutable audit trail
    struct RejectedMarket {
        address creator;
        uint8 riskScore;
        uint256 timestamp;
        string question;
        string reason;
    }
}
