// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Events {
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

    /// @notice Emitted when CRE records a high-risk market rejection on-chain (risk 71-100)
    event MarketRejected(
        uint256 indexed rejectedId,
        address indexed creator,
        uint8 riskScore,
        string question,
        string reason
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
