// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    error Unauthorized();

    error MarketNotActive();
    error MarketPaused();
    error MarketAlreadyResolved();
    error MarketNotFound();

    error DeadlineNotReached();
    error DeadlineAlreadyPassed();

    error InvalidBetAmount();
    error SlippageExceeded();
    error PoolTooLow();

    error InsufficientLiquidity();
    error AlreadySeeded();

    error InvalidOutcome();
    error EscalationFailed();
    error NothingToClaim();
    error AlreadyClaimed();

    error InvalidFeeBps();

    error TransferFailed();

    error InvalidSignature();
}
