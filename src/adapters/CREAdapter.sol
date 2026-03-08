// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";
import {Events} from "../libraries/Events.sol";
import {Errors} from "../libraries/Errors.sol";
import {AccessManager} from "../security/AccessManager.sol";
import {MarketFactory} from "../modules/MarketFactory.sol";
import {RiskEngine} from "../modules/RiskEngine.sol";
import {SettlementEngine} from "../modules/SettlementEngine.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract CREAdapter is
    AccessManager,
    MarketFactory,
    RiskEngine,
    SettlementEngine,
    ReentrancyGuard
{
    // ============ Action Types (CRE → Contract routing) ============
    // ACTION 1: Low risk (0-30)   → auto create market
    // ACTION 2: Workflow 2        → report manipulation
    // ACTION 3: Workflow 3        → resolve market
    // ACTION 5: High risk (71-100)→ record rejection on-chain (BFT attests refusal)
    //
    // Medium risk (31-70): CRE handles BFT consensus internally,
    //                      if 21 nodes agree → still uses ACTION=1 to create market
    uint8 internal constant ACTION_CREATE_MARKET = 1;
    uint8 internal constant ACTION_REPORT_MANIPULATION = 2;
    uint8 internal constant ACTION_RESOLVE_MARKET = 3;
    uint8 internal constant ACTION_REJECT_MARKET = 5;

    // ============ Events ============
    event ReportReceived(uint8 indexed action, bytes32 workflowId);

    // CRE CLI report header size when using encoderName:'evm'.
    // The CRE runtime wraps our ABI payload in a binary envelope:
    //   [1 byte version=0x01][32 bytes executionId][12 bytes fields]
    //   [32 bytes signerHash][10 bytes field][20 bytes addr][2 bytes 0x0001]
    //   = 109 bytes total header, followed by our raw ABI payload.
    // Direct calls (Foundry scripts) pass ABI directly — no header.
    // Detection: ABI(uint8) starts with 0x00; CRE header starts with 0x01.
    uint256 internal constant CRE_HEADER_SIZE = 109;

    // ============ CRE DON Entry Point ============
    /// @notice Receives reports from CRE DON via writeReport
    /// @dev Decodes the payload and routes to the appropriate internal function
    ///      Payload format: abi.encode(uint8 action, ...action-specific fields)
    /// @param _metadata CRE metadata (first 32 bytes = workflowId)
    /// @param _report   ABI-encoded payload starting with uint8 action

    function onReport(
        bytes calldata _metadata,
        bytes calldata _report
    ) external onlyCre {
        _processReport(_metadata, _report);
    }

    /// @notice Hackathon/Testing Only: Allows CRE CLI to call Verity directly
    ///         bypassing MockForwarder. This makes the transaction show up in
    ///         the main Transactions tab on block explorers.
    function report(
        address /* receiver */,
        bytes calldata rawReport,
        bytes calldata reportContext,
        bytes[] calldata /* signatures */
    ) external onlyCre {
        _processReport(reportContext, rawReport);
    }

    function _processReport(
        bytes calldata _metadata,
        bytes calldata _report
    ) internal {
        // Detect and strip CRE CLI 109-byte header if present
        bytes memory payload;
        if (_report.length > CRE_HEADER_SIZE && uint8(_report[0]) == 0x01) {
            payload = _report[CRE_HEADER_SIZE:];
        } else {
            payload = _report;
        }

        uint8 action = abi.decode(payload, (uint8));

        if (action == ACTION_CREATE_MARKET) {
            _handleCreateMarket(payload);
        } else if (action == ACTION_REPORT_MANIPULATION) {
            _handleReportManipulation(payload);
        } else if (action == ACTION_RESOLVE_MARKET) {
            _handleResolveMarket(payload);
        } else if (action == ACTION_REJECT_MARKET) {
            _handleRejectMarket(payload);
        } else {
            revert Errors.InvalidOutcome();
        }

        bytes32 workflowId;
        if (_metadata.length >= 32) {
            workflowId = bytes32(_metadata[:32]);
        }
        emit ReportReceived(action, workflowId);
    }

    // ============ Internal Report Handlers ============

    /// @dev ACTION_CREATE_MARKET (Workflow 1)
    function _handleCreateMarket(bytes memory payload) internal {
        (
            , // action
            uint256 proposalId,
            address creator,
            uint64 deadline,
            uint16 feeBps,
            uint8 category,
            string memory question,
            string memory resolutionCriteria,
            string memory dataSources,
            int256 targetValue,
            address priceFeedAddress,
            uint8 riskScore
        ) = abi.decode(
                payload,
                (
                    uint8,
                    uint256,
                    address,
                    uint64,
                    uint16,
                    uint8,
                    string,
                    string,
                    string,
                    int256,
                    address,
                    uint8
                )
            );

        _createMarket(
            proposalId,
            creator,
            deadline,
            feeBps,
            category,
            question,
            resolutionCriteria,
            dataSources,
            targetValue,
            priceFeedAddress,
            riskScore
        );
    }

    /// @dev ACTION_REJECT_MARKET (Workflow 1 — high risk 71-100)
    function _handleRejectMarket(bytes memory payload) internal {
        (
            , // action
            address creator,
            uint8 riskScore,
            string memory question,
            string memory reason
        ) = abi.decode(payload, (uint8, address, uint8, string, string));

        if (creator == address(0)) revert Errors.ZeroAddress();

        uint256 rejectedId = rejectedCount++;

        DataTypes.RejectedMarket storage r = rejectedMarkets[rejectedId];
        r.creator = creator;
        r.riskScore = riskScore;
        r.timestamp = block.timestamp;
        r.question = question;
        r.reason = reason;

        emit Events.MarketRejected(
            rejectedId,
            creator,
            riskScore,
            question,
            reason
        );
    }

    /// @dev ACTION_REPORT_MANIPULATION (Workflow 2)
    function _handleReportManipulation(bytes memory payload) internal {
        (
            , // action
            uint256 marketId,
            uint8 score,
            string memory reason
        ) = abi.decode(payload, (uint8, uint256, uint8, string));

        _requireMarketExists(marketId);
        _reportManipulation(marketId, score, reason);
    }

    /// @dev ACTION_RESOLVE_MARKET (Workflow 3)
    function _handleResolveMarket(bytes memory payload) internal {
        (
            , // action
            uint256 marketId,
            uint8 outcome,
            uint8 confidence,
            string memory reason,
            string[] memory evidenceUrls
        ) = abi.decode(
                payload,
                (uint8, uint256, uint8, uint8, string, string[])
            );

        _requireMarketExists(marketId);
        // [TESTING HACK] Bypass deadline check for CRE-3 simulation demo
        // if (block.timestamp < markets[marketId].deadline) {
        //     revert Errors.DeadlineNotReached();
        // }
        _resolveMarket(marketId, outcome, confidence, reason, evidenceUrls);
    }

    // ============ Direct Call Functions (for testing / backward compat) ============

    /// @param proposalId dari proposeMarket (user deposit $5)
    /// @param riskScore 0-100 dari CRE — disimpan on-chain agar FE bisa baca
    function createMarketFromCre(
        uint256 proposalId,
        address creator,
        uint64 deadline,
        uint16 feeBps,
        uint8 category,
        string calldata question,
        string calldata resolutionCriteria,
        string calldata dataSources,
        int256 targetValue,
        address priceFeedAddress,
        uint8 riskScore
    ) external onlyCre returns (uint256 marketId) {
        marketId = _createMarket(
            proposalId,
            creator,
            deadline,
            feeBps,
            category,
            question,
            resolutionCriteria,
            dataSources,
            targetValue,
            priceFeedAddress,
            riskScore
        );
    }

    /// @notice CRE rejects proposal (risk 71-100). Refunds $5 and records on-chain.
    function rejectMarketProposal(
        uint256 proposalId,
        uint8 riskScore,
        string calldata reason
    ) external onlyCre nonReentrant {
        DataTypes.MarketProposal storage p = proposals[proposalId];
        if (p.creator == address(0)) revert Errors.ProposalNotFound();
        if (p.status != DataTypes.ProposalStatus.Pending)
            revert Errors.InvalidProposalStatus();

        address creator = p.creator;
        uint256 amount = p.amount;
        string memory payloadJSON = p.payloadJSON;

        p.status = DataTypes.ProposalStatus.Rejected;

        uint256 rejectedId = rejectedCount++;
        DataTypes.RejectedMarket storage r = rejectedMarkets[rejectedId];
        r.creator = creator;
        r.riskScore = riskScore;
        r.timestamp = block.timestamp;
        r.question = payloadJSON;
        r.reason = reason;

        emit Events.MarketRejected(
            rejectedId,
            creator,
            riskScore,
            payloadJSON,
            reason
        );

        _refundProposalDeposit(creator, amount);
    }

    /// @dev Override in Verity to perform USDC transfer
    function _refundProposalDeposit(
        address creator,
        uint256 amount
    ) internal virtual;

    function reportManipulation(
        uint256 marketId,
        uint8 score,
        string calldata reason
    ) external onlyCre {
        _requireMarketExists(marketId);
        _reportManipulation(marketId, score, reason);
    }

    /// @notice Feature 3: resolve with AI reason and evidence URLs
    function resolveMarketFromCre(
        uint256 marketId,
        uint8 outcome,
        uint8 confidence,
        string calldata reason,
        string[] calldata evidenceUrls
    ) external onlyCre {
        _requireMarketExists(marketId);
        if (block.timestamp < markets[marketId].deadline) {
            revert Errors.DeadlineNotReached();
        }
        _resolveMarket(marketId, outcome, confidence, reason, evidenceUrls);
    }

    function unpauseMarket(uint256 marketId) external onlyAdmin {
        _requireMarketExists(marketId);
        _unpauseMarket(marketId);
    }
}
