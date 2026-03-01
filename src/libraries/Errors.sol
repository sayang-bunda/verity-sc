// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    // ACCESS / AUTH
    error Unauthorized();
    error ZeroAddress();
    error InvalidAddress();
    error InvalidSignature();

    // MARKET
    error MarketNotActive();
    error MarketPaused();
    error MarketNotPaused();
    error MarketAlreadyResolved();
    error MarketNotResolved();
    error MarketNotEscalated();
    error MarketNotFound();
    error PendingMarketNotFound();
    error InvalidMarketId();
    error InvalidCategory();
    error VerityContractAlreadySet();

    // DEADLINE
    error DeadlineNotReached();
    error DeadlineAlreadyPassed();

    // AMOUNT / FEE
    error AmountTooLow();
    error AmountTooHigh();
    error InvalidBetAmount();
    error InvalidFeeBps();
    error InvalidSlippage();

    // POOL / LIQUIDITY
    error PoolTooLow();
    error PoolImbalanced();
    error InvalidPool();
    error InsufficientLiquidity();
    error InsufficientShares();
    error AlreadySeeded();
    error SlippageExceeded();

    // OUTCOME / CLAIM / REFUND
    error InvalidOutcome();
    error InvalidConfidence();
    error NothingToClaim();
    error AlreadyClaimed();
    error NoPositionToRefund();
    error EscalationFailed();

    // TRANSFER
    error TransferFailed();
}
