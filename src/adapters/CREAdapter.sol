// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Errors} from "../libraries/Errors.sol";
import {AccessManager} from "../security/AccessManager.sol";
import {MarketFactory} from "../modules/MarketFactory.sol";
import {RiskEngine} from "../modules/RiskEngine.sol";
import {SettlementEngine} from "../modules/SettlementEngine.sol";

abstract contract CREAdapter is AccessManager, MarketFactory, RiskEngine, SettlementEngine {
    // ============ Action Types (CRE → Contract routing) ============
    uint8 internal constant ACTION_CREATE_MARKET = 1;
    uint8 internal constant ACTION_REPORT_MANIPULATION = 2;
    uint8 internal constant ACTION_RESOLVE_MARKET = 3;

    // ============ Events ============
    event ReportReceived(uint8 indexed action, bytes32 workflowId);

    // ============ CRE DON Entry Point ============
    /// @notice Receives reports from CRE DON via writeReport
    /// @dev Decodes the payload and routes to the appropriate internal function
    ///      Pattern: same as UpdateReservesProxy in CRE template
    /// @param metadata CRE metadata (contains workflow info, first 32 bytes = workflowId)
    /// @param report ABI-encoded payload: (uint8 action, ...action-specific data)
    function onReport(bytes calldata metadata, bytes calldata report) external onlyCre {
        // Decode action type from the report (first field)
        uint8 action = abi.decode(report, (uint8));

        if (action == ACTION_CREATE_MARKET) {
            _handleCreateMarket(report);
        } else if (action == ACTION_REPORT_MANIPULATION) {
            _handleReportManipulation(report);
        } else if (action == ACTION_RESOLVE_MARKET) {
            _handleResolveMarket(report);
        } else {
            revert Errors.InvalidOutcome();
        }

        // Extract workflowId from metadata for logging
        bytes32 workflowId;
        if (metadata.length >= 32) {
            workflowId = bytes32(metadata[:32]);
        }
        emit ReportReceived(action, workflowId);
    }

    // ============ Internal Report Handlers ============

    /// @dev Handles ACTION_CREATE_MARKET (Workflow 1)
    ///      Payload: (uint8 action, address creator, uint64 deadline, uint16 feeBps,
    ///               uint8 category, string question, string criteria, string sources)
    function _handleCreateMarket(bytes calldata report) internal {
        (, // skip action (already decoded)
            address creator,
            uint64 deadline,
            uint16 feeBps,
            uint8 category,
            string memory question,
            string memory resolutionCriteria,
            string memory dataSources
        ) = abi.decode(report, (uint8, address, uint64, uint16, uint8, string, string, string));

        if (!hasRole(ADMIN_ROLE, creator)) revert Errors.Unauthorized();
        _createMarket(creator, deadline, feeBps, category, question, resolutionCriteria, dataSources);
    }

    /// @dev Handles ACTION_REPORT_MANIPULATION (Workflow 2)
    ///      Payload: (uint8 action, uint256 marketId, uint8 score, string reason)
    function _handleReportManipulation(bytes calldata report) internal {
        (, // skip action
            uint256 marketId,
            uint8 score,
            string memory reason
        ) = abi.decode(report, (uint8, uint256, uint8, string));

        _requireMarketExists(marketId);
        _reportManipulation(marketId, score, reason);
    }

    /// @dev Handles ACTION_RESOLVE_MARKET (Workflow 3)
    ///      Payload: (uint8 action, uint256 marketId, uint8 outcome, uint8 confidence)
    function _handleResolveMarket(bytes calldata report) internal {
        (, // skip action
            uint256 marketId,
            uint8 outcome,
            uint8 confidence
        ) = abi.decode(report, (uint8, uint256, uint8, uint8));

        _requireMarketExists(marketId);
        if (block.timestamp < markets[marketId].deadline) {
            revert Errors.DeadlineNotReached();
        }
        _resolveMarket(marketId, outcome, confidence);
    }

    // ============ Direct Call Functions (backward compatible, for testing) ============

    function createMarketFromCre(
        address creator,
        uint64 deadline,
        uint16 feeBps,
        uint8 category,
        string calldata question,
        string calldata resolutionCriteria,
        string calldata dataSources
    ) external onlyCre returns (uint256 marketId) {
        if (!hasRole(ADMIN_ROLE, creator)) revert Errors.Unauthorized();
        marketId = _createMarket(creator, deadline, feeBps, category, question, resolutionCriteria, dataSources);
    }

    function reportManipulation(uint256 marketId, uint8 score, string calldata reason) external onlyCre {
        _requireMarketExists(marketId);
        _reportManipulation(marketId, score, reason);
    }

    function resolveMarketFromCre(uint256 marketId, uint8 outcome, uint8 confidence) external onlyCre {
        _requireMarketExists(marketId);
        if (block.timestamp < markets[marketId].deadline) {
            revert Errors.DeadlineNotReached();
        }
        _resolveMarket(marketId, outcome, confidence);
    }

    function unpauseMarket(uint256 marketId) external onlyAdmin {
        _requireMarketExists(marketId);
        _unpauseMarket(marketId);
    }
}
