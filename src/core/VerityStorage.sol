// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";

abstract contract VerityStorage {
    address public immutable USDC;
    address public immutable POSITION_TOKEN;
    uint256 public marketCount;

    mapping(uint256 => DataTypes.Market) internal markets;
    mapping(uint256 => mapping(address => DataTypes.UserPosition))
        internal positions;
    mapping(uint256 => bool) internal seeded;
    mapping(uint256 => mapping(address => bool)) internal claimed;
    mapping(uint256 => uint256) internal accumulatedFees;

    // ── Extended market data ──────────────────────────────────────────────────
    mapping(uint256 => string) internal marketQuestions;
    mapping(uint256 => DataTypes.ResolutionMeta) internal resolutionMeta;
    mapping(uint256 => uint256) internal bettorCounts;
    mapping(uint256 => mapping(address => bool)) internal hasBetted;

    // ── Rejected markets (risk score 71-100, recorded on-chain by CRE) ───────
    uint256 public rejectedCount;
    mapping(uint256 => DataTypes.RejectedMarket) internal rejectedMarkets;

    // ── Pending markets (risk score 31-70, await Admin approval) ─────────────
    uint256 public pendingCount;
    mapping(uint256 => DataTypes.PendingMarket) internal pendingMarkets;

    // ── Feature 1: Anti-spam $5 market proposal deposit ─────────────────────
    uint256 public constant PROPOSAL_DEPOSIT = 5 * 1e6; // $5 USDC (6 decimals)
    uint256 public constant NO_PROPOSAL = type(uint256).max; // sentinel: no deposit (backward compat)
    uint256 public proposalCount;
    mapping(uint256 => DataTypes.MarketProposal) internal proposals;

    // ── Creator deposit (refunded when market resolves) ──────────────────────
    mapping(uint256 => uint256) internal creatorDeposits;

    // ── Risk score (0-100) dari CRE saat approve proposal — FE bisa baca ─────
    mapping(uint256 => uint8) internal marketRiskScores;

    // ── Feature 3: Resolution evidence ──────────────────────────────────────
    mapping(uint256 => string) internal resolutionReasons;
    mapping(uint256 => string[]) internal resolutionEvidenceUrls;

    // ── Market creation requests (Tx 1 — user submits, CRE processes, Tx 2 activates) ──
    uint256 public requestCount;
    mapping(uint256 => DataTypes.MarketRequest) public marketRequests;

    // ── Meta-transactions (Relayer support) ──────────────────────────────────
    mapping(address => uint256) public nonces;

    constructor(address _usdc, address _positionToken) {
        if (_usdc == address(0)) revert Errors.ZeroAddress();
        if (_positionToken == address(0)) revert Errors.ZeroAddress();
        USDC = _usdc;
        POSITION_TOKEN = _positionToken;
    }

    function _requireMarketExists(uint256 marketId) internal view {
        if (markets[marketId].creator == address(0)) {
            revert Errors.MarketNotFound();
        }
    }

    // ── Core market getters ───────────────────────────────────────────────────

    function getMarket(
        uint256 marketId
    ) external view returns (DataTypes.Market memory) {
        return markets[marketId];
    }

    function getPosition(
        uint256 marketId,
        address user
    ) external view returns (DataTypes.UserPosition memory) {
        return positions[marketId][user];
    }

    function isSeeded(uint256 marketId) external view returns (bool) {
        return seeded[marketId];
    }

    function isClaimed(
        uint256 marketId,
        address user
    ) external view returns (bool) {
        return claimed[marketId][user];
    }

    function getAccumulatedFees(
        uint256 marketId
    ) external view returns (uint256) {
        return accumulatedFees[marketId];
    }

    // ── Extended getters (used by CRE workflows) ──────────────────────────────

    function getMarketQuestion(
        uint256 marketId
    ) external view returns (string memory) {
        return marketQuestions[marketId];
    }

    function getBettorCount(uint256 marketId) external view returns (uint256) {
        return bettorCounts[marketId];
    }

    function getResolutionData(
        uint256 marketId
    )
        external
        view
        returns (
            string memory resolutionCriteria,
            string memory dataSources,
            int256 targetValue,
            address priceFeedAddress
        )
    {
        DataTypes.ResolutionMeta storage r = resolutionMeta[marketId];
        return (
            r.resolutionCriteria,
            r.dataSources,
            r.targetValue,
            r.priceFeedAddress
        );
    }

    // ── Proposal getters ────────────────────────────────────────────────────

    function getProposal(uint256 proposalId) external view returns (DataTypes.MarketProposal memory) {
        return proposals[proposalId];
    }

    function getCreatorDeposit(uint256 marketId) external view returns (uint256) {
        return creatorDeposits[marketId];
    }

    /// @notice Risk score (0-100) dari CRE saat approve proposal. 0 = belum diset.
    function getMarketRiskScore(uint256 marketId) external view returns (uint8) {
        return marketRiskScores[marketId];
    }

    function getResolutionEvidence(uint256 marketId)
        external
        view
        returns (string memory reason, string[] memory evidenceUrls)
    {
        return (resolutionReasons[marketId], resolutionEvidenceUrls[marketId]);
    }

    // ── Rejected market getter ─────────────────────────────────────────────────

    function getRejectedMarket(
        uint256 rejectedId
    ) external view returns (DataTypes.RejectedMarket memory) {
        return rejectedMarkets[rejectedId];
    }

    // ── Pending market getter ───────────────────────────────────────────────────

    function getPendingMarket(
        uint256 pendingId
    ) external view returns (DataTypes.PendingMarket memory) {
        return pendingMarkets[pendingId];
    }
}
