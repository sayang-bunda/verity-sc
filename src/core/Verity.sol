// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {CPMMMath} from "../libraries/CPMMMath.sol";
import {CREAdapter} from "../adapters/CREAdapter.sol";

interface IPositionToken {
    function mint(address to, uint256 tokenId, uint256 amount) external;
    function burn(address from, uint256 tokenId, uint256 amount) external;
}

contract Verity is CREAdapter, ReentrancyGuard {
    using SafeERC20 for IERC20;

    function _toU128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) revert Errors.AmountTooHigh();
        // casting to 'uint128' is safe because we check overflow above
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint128(value);
    }

    constructor(
        address _usdc,
        address _positionToken,
        address admin,
        address cre
    ) {
        if (_usdc == address(0) || _positionToken == address(0)) {
            revert Errors.ZeroAddress();
        }
        if (admin == address(0) || cre == address(0)) {
            revert Errors.ZeroAddress();
        }
        usdc = _usdc;
        positionToken = _positionToken;
        _setupRoles(admin, cre);
    }

    function seedLiquidity(
        uint256 marketId,
        uint256 amount
    ) external nonReentrant {
        DataTypes.Market storage m = markets[marketId];
        if (m.creator != msg.sender) revert Errors.Unauthorized();
        if (m.status != uint8(DataTypes.MarketStatus.Active)) {
            revert Errors.MarketNotActive();
        }
        if (seeded[marketId]) revert Errors.AlreadySeeded();

        if (amount % 2 != 0) revert Errors.AmountTooLow();
        uint128 half = _toU128(amount / 2);
        CPMMMath.validateInitialPools(half, half);

        seeded[marketId] = true;
        m.poolYes = half;
        m.poolNo = half;

        IERC20(usdc).safeTransferFrom(msg.sender, address(this), amount);

        emit Events.LiquiditySeeded(marketId, amount);
    }

    function placeBet(
        uint256 marketId,
        uint256 amount,
        bool isYes,
        uint256 minShares
    ) external nonReentrant {
        DataTypes.Market storage m = markets[marketId];
        if (m.status != uint8(DataTypes.MarketStatus.Active)) {
            revert Errors.MarketNotActive();
        }
        if (!seeded[marketId]) revert Errors.InsufficientLiquidity();
        if (block.timestamp >= m.deadline) {
            revert Errors.DeadlineAlreadyPassed();
        }

        CPMMMath.validateAmount(amount);

        (
            uint256 shares,
            uint256 feeAmount,
            uint256 newPoolYes,
            uint256 newPoolNo
        ) = CPMMMath.calcShares(amount, m.poolYes, m.poolNo, m.feeBps, isYes);

        if (shares < minShares) revert Errors.SlippageExceeded();

        m.poolYes = _toU128(newPoolYes);
        m.poolNo = _toU128(newPoolNo);
        m.totalVolume += amount;
        accumulatedFees[marketId] += feeAmount;

        DataTypes.UserPosition storage pos = positions[marketId][msg.sender];
        if (isYes) {
            pos.yesShares += _toU128(shares);
            pos.totalBetYes += _toU128(amount);
        } else {
            pos.noShares += _toU128(shares);
            pos.totalBetNo += _toU128(amount);
        }

        IERC20(usdc).safeTransferFrom(msg.sender, address(this), amount);

        IPositionToken pt = IPositionToken(positionToken);
        uint256 tokenId = isYes ? marketId * 2 : marketId * 2 + 1;
        pt.mint(msg.sender, tokenId, shares);

        emit Events.BetPlaced(marketId, msg.sender, isYes, amount, shares);
    }

    function claimPayout(uint256 marketId) external nonReentrant {
        DataTypes.Market storage m = markets[marketId];
        if (m.status != uint8(DataTypes.MarketStatus.Resolved)) {
            revert Errors.MarketNotResolved();
        }
        if (claimed[marketId][msg.sender]) revert Errors.AlreadyClaimed();

        DataTypes.UserPosition storage pos = positions[marketId][msg.sender];
        uint256 payout;

        if (m.outcome == uint8(DataTypes.MarketOutcome.Yes)) {
            if (pos.yesShares == 0) revert Errors.NothingToClaim();
            payout = CPMMMath.calcPayout(pos.yesShares, m.poolYes, m.poolNo);
        } else if (m.outcome == uint8(DataTypes.MarketOutcome.No)) {
            if (pos.noShares == 0) revert Errors.NothingToClaim();
            payout = CPMMMath.calcPayout(pos.noShares, m.poolNo, m.poolYes);
        } else {
            revert Errors.InvalidOutcome();
        }

        claimed[marketId][msg.sender] = true;

        IPositionToken pt = IPositionToken(positionToken);
        if (pos.yesShares > 0) {
            pt.burn(msg.sender, marketId * 2, pos.yesShares);
        }
        if (pos.noShares > 0) {
            pt.burn(msg.sender, marketId * 2 + 1, pos.noShares);
        }

        IERC20(usdc).safeTransfer(msg.sender, payout);

        emit Events.PayoutClaimed(marketId, msg.sender, payout);
    }

    function claimRefund(uint256 marketId) external nonReentrant {
        DataTypes.Market storage m = markets[marketId];
        if (m.status != uint8(DataTypes.MarketStatus.Escalated)) {
            revert Errors.MarketNotEscalated();
        }
        if (claimed[marketId][msg.sender]) revert Errors.AlreadyClaimed();

        DataTypes.UserPosition storage pos = positions[marketId][msg.sender];
        if (pos.totalBetYes == 0 && pos.totalBetNo == 0) {
            revert Errors.NoPositionToRefund();
        }

        uint256 refundAmount = uint256(pos.totalBetYes) +
            uint256(pos.totalBetNo);

        claimed[marketId][msg.sender] = true;

        IPositionToken pt = IPositionToken(positionToken);
        if (pos.yesShares > 0) {
            pt.burn(msg.sender, marketId * 2, pos.yesShares);
        }
        if (pos.noShares > 0) {
            pt.burn(msg.sender, marketId * 2 + 1, pos.noShares);
        }

        IERC20(usdc).safeTransfer(msg.sender, refundAmount);

        emit Events.RefundProcessed(marketId, msg.sender, refundAmount);
    }

    function withdrawFees(uint256 marketId) external nonReentrant {
        DataTypes.Market storage m = markets[marketId];
        if (m.creator != msg.sender) revert Errors.Unauthorized();
        if (m.status != uint8(DataTypes.MarketStatus.Resolved)) {
            revert Errors.MarketNotResolved();
        }

        uint256 fees = accumulatedFees[marketId];
        if (fees == 0) revert Errors.NothingToClaim();

        accumulatedFees[marketId] = 0;

        IERC20(usdc).safeTransfer(msg.sender, fees);

        emit Events.FeeWithdrawn(marketId, msg.sender, fees);
    }
}
