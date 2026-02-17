// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Events {
    event MarketCreated(
        uint256 indexed marketId,
        address indexed creator,
        string question,
        string resolutionCriteria,
        string dataSources,
        uint64 deadline,
        uint16 feeBps
    );

    event BetPlaced(uint256 indexed marketId, address indexed user, bool isYes, uint256 amount, uint256 shares);

    event LiquiditySeeded(uint256 indexed marketId, uint256 amount);

    event LiquidityWithdrawn(uint256 indexed marketId, uint256 amount);

    event SettlementRequested(uint256 indexed marketId);

    event MarketResolved(uint256 indexed marketId, uint8 outcome);

    event MarketEscalated(uint256 indexed marketId, uint8 confidence);

    event ManipulationAlert(uint256 indexed marketId, uint8 score, string reason);

    event MarketPaused(uint256 indexed marketId);

    event MarketUnpaused(uint256 indexed marketId);

    event PayoutClaimed(uint256 indexed marketId, address indexed user, uint256 amount);

    event FeeWithdrawn(uint256 indexed marketId, address indexed creator, uint256 amount);
}
