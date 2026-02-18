// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    error Unauthorized();

    error MarketNotActive();
    error MarketPaused();
    error MarketNotPaused();
    error MarketAlreadyResolved();
    error MarketNotFound();

    error DeadlineNotReached();
    error DeadlineAlreadyPassed();

    error AmountTooLow();
    error AmountTooHigh();
    error SlippageExceeded();
    error InvalidSlippage();
    error InsufficientShares();

    error PoolTooLow();
    error PoolImbalanced();
    error InvalidPool();
    error InsufficientLiquidity();
    error AlreadySeeded();

    error InvalidOutcome();
    error InvalidConfidence();
    error InvalidCategory();
    error InvalidFeeBps();

    error EscalationFailed();
    error NothingToClaim();
    error AlreadyClaimed();
    error NoPositionToRefund();

    error TransferFailed();
    error InvalidSignature();
    error ZeroAddress();
    error MarketNotResolved();
    error MarketNotEscalated();
}
