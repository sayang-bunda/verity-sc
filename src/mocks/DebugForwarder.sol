// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title DebugForwarder
 * @notice Acts as a receiver for CRE CLI writeReport. Emits rawReport bytes
 *         as an event WITHOUT forwarding to Verity — used purely to inspect
 *         what the CRE SDK encodes as rawReport on-chain.
 *
 * Deploy this as the receiver (writeReportReceiver in config.staging.json),
 * then run simulate --broadcast, then look at the emitted RawReportReceived
 * event on BaseScan to see the actual bytes.
 */
contract DebugForwarder {
    event RawReportReceived(
        bytes reportContext,
        bytes rawReport,
        uint256 rawReportLen
    );

    /// @notice Called by Keystone Forwarder — same interface as IReceiver
    function onReport(
        bytes calldata reportContext,
        bytes calldata rawReport
    ) external {
        emit RawReportReceived(reportContext, rawReport, rawReport.length);
    }
}
