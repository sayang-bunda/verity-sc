// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Events {
    /// @notice Emitted when a user records a market creation request on-chain (Tx 1).
    /// @dev CRE-1 Workflow listens for this event to trigger DON consensus.
    ///      After BFT consensus, CRE calls onReport() to activate the market (Tx 2).
    event MarketCreationRequested(
        uint256 indexed requestId,
        address indexed creator,
        string question,
        uint8 category,
        uint64 deadline,
        uint16 feeBps
    );

    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        uint8 category,
        uint64 deadline,
        uint16 feeBps,
        string question,
        string resolutionCriteria,
        string dataSources
    );

    /// @notice Emitted when user proposes a market with $5 deposit (Feature 1 — CRE listens)
    event MarketProposed(
        uint256 indexed proposalId,
        address indexed creator,
        string payloadJSON
    );

    /// @notice Emitted when CRE records a high-risk market rejection on-chain (risk 71-100)
    event MarketRejected(
        uint256 indexed rejectedId,
        address indexed creator,
        uint8 riskScore,
        string question,
        string reason
    );

    /// @notice Emitted when CRE queues a medium-risk market (31-70) for Admin approval
    event PendingMarketQueued(
        uint256 indexed pendingId,
        uint256 proposalId,
        address indexed creator,
        uint8 riskScore
    );

    event LiquiditySeeded(
        uint256 indexed marketId,
        address indexed creator,
        uint128 poolYes,
        uint128 poolNo
    );

    event BetPlaced(
        uint256 indexed marketId,
        address indexed user,
        bool isYes,
        uint256 amount,
        uint256 shares,
        uint256 feeAmount
    );

    event MarketResolved(
        uint256 indexed marketId,
        uint8 outcome,
        uint8 confidence
    );

    /// @notice Emitted when market resolved with AI evidence (Feature 3)
    event MarketResolvedWithEvidence(
        uint256 indexed marketId,
        uint8 outcome,
        uint8 confidence,
        string reason,
        string[] evidenceUrls
    );
    event MarketEscalated(uint256 indexed marketId, uint8 confidence);
    event ManipulationDetected(
        uint256 indexed marketId,
        uint8 score,
        string reason
    );
    event MarketPaused(uint256 indexed marketId, uint8 score);
    event MarketUnpaused(uint256 indexed marketId);

    event SettlementRequested(
        uint256 indexed marketId,
        address indexed requester
    );

    event PayoutClaimed(
        uint256 indexed marketId,
        address indexed user,
        uint256 amount
    );
    event PayoutClaimedByRelayer(
        uint256 indexed marketId,
        address indexed user,
        address indexed relayer,
        uint256 amount,
        uint256 gasReward
    );
    event RefundProcessed(
        uint256 indexed marketId,
        address indexed user,
        uint256 amount
    );
    event FeeWithdrawn(
        uint256 indexed marketId,
        address indexed creator,
        uint256 amount
    );
}
