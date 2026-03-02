// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {VerityStorage} from "../core/VerityStorage.sol";

abstract contract MarketFactory is VerityStorage {
    uint16 public constant MAX_FEE_BPS = 1000;

    /// @dev proposalId wajib valid (dari proposeMarket). riskScore (0-100) disimpan agar FE bisa baca.
    function _createMarket(
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
    ) internal returns (uint256 marketId) {
        if (creator == address(0)) revert Errors.ZeroAddress();
        if (deadline <= block.timestamp) revert Errors.DeadlineAlreadyPassed();
        if (feeBps > MAX_FEE_BPS) revert Errors.InvalidFeeBps();
        if (category > uint8(type(DataTypes.MarketCategory).max)) {
            revert Errors.InvalidCategory();
        }
        if (proposalId == NO_PROPOSAL) revert Errors.ProposalRequired();

        DataTypes.MarketProposal storage p = proposals[proposalId];
        if (p.creator == address(0)) revert Errors.ProposalNotFound();
        if (p.status != DataTypes.ProposalStatus.Pending)
            revert Errors.InvalidProposalStatus();
        if (p.creator != creator) revert Errors.Unauthorized();
        p.status = DataTypes.ProposalStatus.Approved;

        marketId = marketCount++;
        creatorDeposits[marketId] = p.amount;
        marketRiskScores[marketId] = riskScore;

        // Auto-seed liquidity (200 USDC total) from Admin/Contract balance
        // Note: 100 USDC for YES, 100 USDC for NO. (6 decimals for USDC)
        uint128 initialLiquidityPerSide = 100 * 1e6; 
        DataTypes.Market storage m = markets[marketId];
        m.poolYes = initialLiquidityPerSide;
        m.poolNo = initialLiquidityPerSide;
        seeded[marketId] = true;

        emit Events.LiquiditySeeded(
            marketId,
            msg.sender, // Admin/CRE as the provider
            initialLiquidityPerSide,
            initialLiquidityPerSide
        );
        m.creator = creator;
        m.deadline = deadline;
        m.feeBps = feeBps;
        m.status = uint8(DataTypes.MarketStatus.Active);
        m.outcome = uint8(DataTypes.MarketOutcome.Unresolved);
        m.category = category;

        marketQuestions[marketId] = question;

        DataTypes.ResolutionMeta storage r = resolutionMeta[marketId];
        r.resolutionCriteria = resolutionCriteria;
        r.dataSources = dataSources;
        r.targetValue = targetValue;
        r.priceFeedAddress = priceFeedAddress;

        emit Events.MarketCreated(
            marketId,
            creator,
            category,
            deadline,
            feeBps,
            question,
            resolutionCriteria,
            dataSources
        );
    }
}
