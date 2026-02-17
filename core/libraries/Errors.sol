// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ============ Pool & Liquidity Errors ============
error PoolTooLow();
error PoolImbalanced();
error InsufficientShares();

// ============ Amount & Fee Errors ============
error AmountTooLow();
error AmountTooHigh();
error FeeTooHigh();

// ============ Market State Errors ============
error InvalidDeadline();
error DeadlineTooFar();
error MarketNotActive();
error MarketAlreadyResolved();
error MarketPaused();

// ============ Settlement Errors ============
error InvalidOutcome();
error InvalidConfidence();
error AlreadyClaimed();
error NoPositionToRefund();

// ============ Trading Protection Errors ============
error SlippageExceeded();
error InvalidSlippage();

// ============ Access Control Errors ============
error Unauthorized();
error OnlyCRE();
error OnlyAdmin();
error OnlyCreator();

// ============ General Errors ============
error InvalidPool();
error ZeroAddress();
error InvalidMarketId();
error InvalidCategory();
