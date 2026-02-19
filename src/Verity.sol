// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {IERC20}          from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20}       from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


import {DataTypes}      from "./libraries/DataTypes.sol";
import {Errors}         from "./libraries/Errors.sol";
import {Events}         from "./libraries/Events.sol";
import {CPMMMath}       from "./libraries/CPMMMath.sol";


import {VerityStorage}     from "./core/VerityStorage.sol";
import {AccessManager}     from "./security/AccessManager.sol";
import {MarketFactory}     from "./modules/MarketFactory.sol";
import {BettingEngine}     from "./modules/BettingEngine.sol";
import {SettlementEngine}  from "./modules/SettlementEngine.sol";
import {RiskEngine}        from "./modules/RiskEngine.sol";
import {CREAdapter}        from "./adapters/CREAdapter.sol";


interface IPositionToken {
    function mint(address to, uint256 tokenId, uint256 amount) external;
    function burn(address from, uint256 tokenId, uint256 amount) external;
    function getYesTokenId(uint256 marketId) external pure returns (uint256);
    function getNoTokenId(uint256 marketId) external pure returns (uint256);
}


contract Verity is ReentrancyGuard, CREAdapter, BettingEngine {
    using SafeERC20 for IERC20;


    function _toU128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) revert Errors.AmountTooHigh();
        return uint128(value);
    }


    constructor(
        address _usdc,
        address _positionToken,
        address _admin,
        address _cre
    ) {
        if (_usdc          == address(0)) revert Errors.ZeroAddress();
        if (_positionToken == address(0)) revert Errors.ZeroAddress();


        usdc          = _usdc;
        positionToken = _positionToken;


        _setupRoles(_admin, _cre);
    }


    function seedLiquidity(
        uint256 marketId,
        uint128 amountYes,
        uint128 amountNo
    ) external nonReentrant {
        DataTypes.Market storage m = markets[marketId];


        if (m.creator != msg.sender)                               revert Errors.Unauthorized();
        if (m.status  != uint8(DataTypes.MarketStatus.Active))     revert Errors.MarketNotActive();
        if (seeded[marketId])                                      revert Errors.AlreadySeeded();


        CPMMMath.validateInitialPools(amountYes, amountNo);


        seeded[marketId] = true;
        m.poolYes       += amountYes;
        m.poolNo        += amountNo;


        IERC20(usdc).safeTransferFrom(msg.sender, address(this), uint256(amountYes) + uint256(amountNo));


        emit Events.LiquiditySeeded(marketId, msg.sender, m.poolYes, m.poolNo);
    }


    function placeBet(
        uint256 marketId,
        uint256 amount,
        bool    isYes,
        uint256 minShares
    ) external nonReentrant {
        DataTypes.Market storage m = markets[marketId];


        if (m.status != uint8(DataTypes.MarketStatus.Active)) revert Errors.MarketNotActive();
        if (!seeded[marketId])                                 revert Errors.InsufficientLiquidity();
        if (block.timestamp >= m.deadline)                     revert Errors.DeadlineAlreadyPassed();


        (
            uint256 shares,
            uint256 feeAmount,
            uint256 newPoolYes,
            uint256 newPoolNo
        ) = _calculateBet(amount, m.poolYes, m.poolNo, m.feeBps, isYes);


        if (shares < minShares) revert Errors.SlippageExceeded();


        m.poolYes                  = _toU128(newPoolYes);
        m.poolNo                   = _toU128(newPoolNo);
        m.totalVolume             += amount;
        accumulatedFees[marketId] += feeAmount;


        DataTypes.UserPosition storage pos = positions[marketId][msg.sender];
        if (isYes) {
            pos.yesShares   += _toU128(shares);
            pos.totalBetYes += _toU128(amount);
        } else {
            pos.noShares    += _toU128(shares);
            pos.totalBetNo  += _toU128(amount);
        }


        IERC20(usdc).safeTransferFrom(msg.sender, address(this), amount);


        uint256 tokenId = isYes
            ? IPositionToken(positionToken).getYesTokenId(marketId)
            : IPositionToken(positionToken).getNoTokenId(marketId);
        IPositionToken(positionToken).mint(msg.sender, tokenId, shares);


        emit Events.BetPlaced(marketId, msg.sender, isYes, amount, shares, feeAmount);
    }


    function claimPayout(uint256 marketId) external nonReentrant {
        DataTypes.Market storage m = markets[marketId];


        if (m.status != uint8(DataTypes.MarketStatus.Resolved)) revert Errors.MarketNotResolved();
        if (claimed[marketId][msg.sender])                       revert Errors.AlreadyClaimed();


        DataTypes.UserPosition storage pos = positions[marketId][msg.sender];


        uint256 payout = _calculatePayout(
            pos.yesShares, pos.noShares, m.poolYes, m.poolNo, m.outcome
        );
        if (payout == 0) revert Errors.NothingToClaim();


        claimed[marketId][msg.sender] = true;


        bool isYesWin = m.outcome == uint8(DataTypes.MarketOutcome.Yes);
        uint256 tokenId = isYesWin
            ? IPositionToken(positionToken).getYesTokenId(marketId)
            : IPositionToken(positionToken).getNoTokenId(marketId);
        uint256 shares = isYesWin ? pos.yesShares : pos.noShares;


        if (shares > 0) IPositionToken(positionToken).burn(msg.sender, tokenId, shares);


        IERC20(usdc).safeTransfer(msg.sender, payout);
        emit Events.PayoutClaimed(marketId, msg.sender, payout);
    }


    function claimRefund(uint256 marketId) external nonReentrant {
        DataTypes.Market storage m = markets[marketId];


        if (m.status != uint8(DataTypes.MarketStatus.Escalated)) revert Errors.MarketNotEscalated();
        if (claimed[marketId][msg.sender])                        revert Errors.AlreadyClaimed();


        DataTypes.UserPosition storage pos = positions[marketId][msg.sender];
        uint256 refund = _calculateRefund(pos.totalBetYes, pos.totalBetNo);


        claimed[marketId][msg.sender] = true;


        if (pos.yesShares > 0) {
            IPositionToken(positionToken).burn(
                msg.sender,
                IPositionToken(positionToken).getYesTokenId(marketId),
                pos.yesShares
            );
        }
        if (pos.noShares > 0) {
            IPositionToken(positionToken).burn(
                msg.sender,
                IPositionToken(positionToken).getNoTokenId(marketId),
                pos.noShares
            );
        }


        IERC20(usdc).safeTransfer(msg.sender, refund);
        emit Events.RefundProcessed(marketId, msg.sender, refund);
    }


    function withdrawFees(uint256 marketId) external nonReentrant {
        DataTypes.Market storage m = markets[marketId];


        if (m.creator != msg.sender) revert Errors.Unauthorized();
        if (m.status != uint8(DataTypes.MarketStatus.Resolved)) revert Errors.MarketNotResolved();


        uint256 fees = accumulatedFees[marketId];
        if (fees == 0) revert Errors.NothingToClaim();


        accumulatedFees[marketId] = 0;
        IERC20(usdc).safeTransfer(msg.sender, fees);


        emit Events.FeeWithdrawn(marketId, msg.sender, fees);
    }
}



