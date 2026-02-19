// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    error Unauthorized();
    error ZeroAddress();
    error InvalidAddress();

    error MarketNotActive();
    error MarketPaused();
    error MarketAlreadyResolved();
    error MarketNotFound();
    error InvalidMarketId();

    error DeadlineNotReached();
    error DeadlineAlreadyPassed();

    error AmountTooLow();
    error AmountTooHigh();
    error InvalidFeeBps();

    error PoolTooLow();
    error PoolImbalanced();
    error InsufficientLiquidity();
    error AlreadySeeded();

    error SlippageExceeded();

    error InvalidOutcome();
    error InvalidConfidence();
    error NothingToClaim();
    error AlreadyClaimed();
    error NoPositionToRefund();

    error InvalidCategory();
    error TransferFailed();
    error VerityContractAlreadySet();
}
