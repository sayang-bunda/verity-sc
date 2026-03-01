// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {DataTypes} from "./libraries/DataTypes.sol";
import {Errors} from "./libraries/Errors.sol";
import {Events} from "./libraries/Events.sol";
import {CPMMMath} from "./libraries/CPMMMath.sol";

import {BettingEngine} from "./modules/BettingEngine.sol";
import {CREAdapter} from "./adapters/CREAdapter.sol";
import {VerityStorage} from "./core/VerityStorage.sol";

interface IPositionToken {
    function mint(address to, uint256 tokenId, uint256 amount) external;
    function burn(address from, uint256 tokenId, uint256 amount) external;
}

contract Verity is ReentrancyGuard, CREAdapter, BettingEngine {
    using SafeERC20 for IERC20;

    // ============ EIP-712 Types ============
    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    bytes32 private constant PLACE_BET_TYPEHASH =
        keccak256(
            "PlaceBet(uint256 marketId,address relayer,uint256 amount,bool isYes,uint256 minShares,uint256 relayerFee,uint256 nonce,uint256 deadline)"
        );
    bytes32 private constant CLAIM_PAYOUT_TYPEHASH =
        keccak256(
            "ClaimPayout(uint256 marketId,address relayer,uint256 relayerFee,uint256 nonce,uint256 deadline)"
        );
    bytes32 private constant SEED_LIQUIDITY_TYPEHASH =
        keccak256(
            "SeedLiquidity(uint256 marketId,address relayer,uint128 amountYes,uint128 amountNo,uint256 relayerFee,uint256 nonce,uint256 deadline)"
        );
    bytes32 private constant REQUEST_SETTLEMENT_TYPEHASH =
        keccak256(
            "RequestSettlement(uint256 marketId,address relayer,uint256 nonce,uint256 deadline)"
        );
    bytes32 private constant WITHDRAW_FEES_TYPEHASH =
        keccak256(
            "WithdrawFees(uint256 marketId,address relayer,uint256 relayerFee,uint256 nonce,uint256 deadline)"
        );

    bytes32 public immutable DOMAIN_SEPARATOR;

    function _toU128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) revert Errors.AmountTooHigh();
        // casting to 'uint128' is safe because we check overflow above
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint128(value);
    }

    constructor(
        address _usdc,
        address _positionToken,
        address _admin,
        address _cre
    ) VerityStorage(_usdc, _positionToken) {
        _setupRoles(_admin, _cre);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes("Verity")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    // ============ Meta-Transaction Helpers ============

    function _getVRS(
        bytes memory signature
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        if (signature.length != 65) revert Errors.InvalidAddress();
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
    }

    function seedLiquidity(
        uint256 marketId,
        uint128 amountYes,
        uint128 amountNo
    ) external nonReentrant {
        _requireMarketExists(marketId);
        DataTypes.Market storage m = markets[marketId];

        if (m.creator != msg.sender) revert Errors.Unauthorized();
        if (m.status != uint8(DataTypes.MarketStatus.Active)) {
            revert Errors.MarketNotActive();
        }
        if (seeded[marketId]) revert Errors.AlreadySeeded();

        CPMMMath.validateInitialPools(amountYes, amountNo);

        seeded[marketId] = true;
        m.poolYes = amountYes;
        m.poolNo = amountNo;

        IERC20(USDC).safeTransferFrom(
            msg.sender,
            address(this),
            uint256(amountYes) + uint256(amountNo)
        );

        emit Events.LiquiditySeeded(marketId, msg.sender, m.poolYes, m.poolNo);
    }

    /// @notice Gasless seed liquidity via meta-transaction
    function seedLiquidityWithSignature(
        uint256 marketId,
        uint128 amountYes,
        uint128 amountNo,
        uint256 relayerFee,
        uint256 deadline,
        bytes calldata signature
    ) external onlyRelayer nonReentrant {
        if (block.timestamp > deadline) revert Errors.DeadlineAlreadyPassed();

        bytes32 structHash = keccak256(
            abi.encode(
                SEED_LIQUIDITY_TYPEHASH,
                marketId,
                msg.sender,
                amountYes,
                amountNo,
                relayerFee,
                nonces[tx.origin]++,
                deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = _getVRS(signature);
        address user = ecrecover(hash, v, r, s);
        if (user == address(0)) revert Errors.InvalidAddress();

        _requireMarketExists(marketId);
        DataTypes.Market storage m = markets[marketId];

        if (m.creator != user) revert Errors.Unauthorized();
        if (m.status != uint8(DataTypes.MarketStatus.Active)) revert Errors.MarketNotActive();
        if (seeded[marketId]) revert Errors.AlreadySeeded();

        CPMMMath.validateInitialPools(amountYes, amountNo);

        seeded[marketId] = true;
        m.poolYes = amountYes;
        m.poolNo = amountNo;

        uint256 total = uint256(amountYes) + uint256(amountNo);
        IERC20(USDC).safeTransferFrom(user, address(this), total + relayerFee);
        if (relayerFee > 0) {
            IERC20(USDC).safeTransfer(msg.sender, relayerFee);
        }

        emit Events.LiquiditySeeded(marketId, user, m.poolYes, m.poolNo);
    }

    function placeBet(
        uint256 marketId,
        uint256 amount,
        bool isYes,
        uint256 minShares
    ) external nonReentrant {
        _placeBet(
            marketId,
            msg.sender,
            amount,
            isYes,
            minShares,
            0,
            address(0)
        );
    }

    /// @notice Gasless betting via meta-transaction
    function placeBetWithSignature(
        uint256 marketId,
        uint256 amount,
        bool isYes,
        uint256 minShares,
        uint256 relayerFee,
        uint256 deadline,
        bytes calldata signature
    ) external onlyRelayer nonReentrant {
        if (block.timestamp > deadline) revert Errors.DeadlineAlreadyPassed();

        bytes32 structHash = keccak256(
            abi.encode(
                PLACE_BET_TYPEHASH,
                marketId,
                msg.sender, // Only the caller can be the designated relayer
                amount,
                isYes,
                minShares,
                relayerFee,
                nonces[tx.origin]++,
                deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = _getVRS(signature);
        address user = ecrecover(hash, v, r, s);
        if (user == address(0)) revert Errors.InvalidAddress();

        _placeBet(
            marketId,
            user,
            amount,
            isYes,
            minShares,
            relayerFee,
            msg.sender
        );
    }

    function _placeBet(
        uint256 marketId,
        address user,
        uint256 amount,
        bool isYes,
        uint256 minShares,
        uint256 relayerFee,
        address relayer
    ) internal {
        _requireMarketExists(marketId);
        DataTypes.Market storage m = markets[marketId];

        if (m.status != uint8(DataTypes.MarketStatus.Active)) {
            revert Errors.MarketNotActive();
        }
        if (!seeded[marketId]) revert Errors.InsufficientLiquidity();
        if (block.timestamp >= m.deadline) {
            revert Errors.DeadlineAlreadyPassed();
        }

        (
            uint256 shares,
            uint256 feeAmount,
            uint256 newPoolYes,
            uint256 newPoolNo
        ) = _calculateBet(amount, m.poolYes, m.poolNo, m.feeBps, isYes);

        if (shares < minShares) revert Errors.SlippageExceeded();

        m.poolYes = _toU128(newPoolYes);
        m.poolNo = _toU128(newPoolNo);
        m.totalVolume += amount;
        accumulatedFees[marketId] += feeAmount;

        DataTypes.UserPosition storage pos = positions[marketId][user];
        if (isYes) {
            pos.yesShares += _toU128(shares);
            pos.totalBetYes += _toU128(amount);
        } else {
            pos.noShares += _toU128(shares);
            pos.totalBetNo += _toU128(amount);
        }

        // Track unique bettors
        if (!hasBetted[marketId][user]) {
            hasBetted[marketId][user] = true;
            bettorCounts[marketId]++;
        }

        // Pull amount + relayer fee (relayerFee is 0 if calling directly)
        IERC20(USDC).safeTransferFrom(user, address(this), amount + relayerFee);

        // Distribute relayer fee if applicable
        if (relayerFee > 0 && relayer != address(0)) {
            IERC20(USDC).safeTransfer(relayer, relayerFee);
        }

        uint256 tokenId = isYes ? marketId * 2 : marketId * 2 + 1;
        IPositionToken(POSITION_TOKEN).mint(user, tokenId, shares);

        emit Events.BetPlaced(marketId, user, isYes, amount, shares, feeAmount);
    }

    /// @notice Request settlement for a market after its deadline has passed.
    ///         Emits SettlementRequested which triggers CRE Workflow 3.
    function requestSettlement(uint256 marketId) external {
        _requireMarketExists(marketId);
        DataTypes.Market storage m = markets[marketId];

        if (block.timestamp < m.deadline) revert Errors.DeadlineNotReached();
        if (m.status == uint8(DataTypes.MarketStatus.Resolved))
            revert Errors.MarketAlreadyResolved();

        emit Events.SettlementRequested(marketId, msg.sender);
    }

    /// @notice Gasless request settlement via meta-transaction
    function requestSettlementWithSignature(
        uint256 marketId,
        uint256 deadline,
        bytes calldata signature
    ) external onlyRelayer {
        if (block.timestamp > deadline) revert Errors.DeadlineAlreadyPassed();

        bytes32 structHash = keccak256(
            abi.encode(
                REQUEST_SETTLEMENT_TYPEHASH,
                marketId,
                msg.sender,
                nonces[tx.origin]++,
                deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = _getVRS(signature);
        address user = ecrecover(hash, v, r, s);
        if (user == address(0)) revert Errors.InvalidAddress();

        _requireMarketExists(marketId);
        DataTypes.Market storage m = markets[marketId];

        if (block.timestamp < m.deadline) revert Errors.DeadlineNotReached();
        if (m.status == uint8(DataTypes.MarketStatus.Resolved))
            revert Errors.MarketAlreadyResolved();

        emit Events.SettlementRequested(marketId, user);
    }

    function claimPayout(uint256 marketId) external nonReentrant {
        _claimPayout(marketId, msg.sender, 0, address(0));
    }

    /// @notice Gasless payout via meta-transaction
    function claimPayoutWithSignature(
        uint256 marketId,
        uint256 relayerFee,
        uint256 deadline,
        bytes calldata signature
    ) external onlyRelayer nonReentrant {
        if (block.timestamp > deadline) revert Errors.DeadlineAlreadyPassed();

        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_PAYOUT_TYPEHASH,
                marketId,
                msg.sender,
                relayerFee,
                nonces[tx.origin]++,
                deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = _getVRS(signature);
        address user = ecrecover(hash, v, r, s);
        if (user == address(0)) revert Errors.InvalidAddress();

        _claimPayout(marketId, user, relayerFee, msg.sender);
    }

    /// @notice Allows CRE to claim payout on behalf of a user, with a gas reward.
    function claimPayoutFromCre(
        uint256 marketId,
        address user,
        uint256 gasReward
    ) external onlyCre nonReentrant {
        _claimPayout(marketId, user, gasReward, msg.sender);
    }

    /// @dev Implementation of abstract CREAdapter function.
    function _claimPayoutByRelayer(
        uint256 marketId,
        address user,
        uint256 gasReward
    ) internal override {
        _claimPayout(marketId, user, gasReward, msg.sender);
    }

    function _claimPayout(
        uint256 marketId,
        address user,
        uint256 gasReward,
        address relayer
    ) internal {
        _requireMarketExists(marketId);
        DataTypes.Market storage m = markets[marketId];

        if (m.status != uint8(DataTypes.MarketStatus.Resolved)) {
            revert Errors.MarketNotResolved();
        }
        if (claimed[marketId][user]) revert Errors.AlreadyClaimed();

        DataTypes.UserPosition storage pos = positions[marketId][user];

        uint256 totalPayout = _calculatePayout(
            pos.yesShares,
            pos.noShares,
            m.poolYes,
            m.poolNo,
            m.outcome
        );
        if (totalPayout == 0) revert Errors.NothingToClaim();
        if (totalPayout <= gasReward) revert Errors.InsufficientLiquidity();

        claimed[marketId][user] = true;

        bool isYesWin = m.outcome == uint8(DataTypes.MarketOutcome.Yes);
        uint256 tokenId = isYesWin ? marketId * 2 : marketId * 2 + 1;
        uint256 shares = isYesWin ? pos.yesShares : pos.noShares;

        if (shares > 0) {
            IPositionToken(POSITION_TOKEN).burn(user, tokenId, shares);
        }

        if (gasReward > 0) {
            uint256 userAmount = totalPayout - gasReward;
            IERC20(USDC).safeTransfer(user, userAmount);
            IERC20(USDC).safeTransfer(relayer, gasReward);
            emit Events.PayoutClaimedByRelayer(
                marketId,
                user,
                relayer,
                totalPayout,
                gasReward
            );
        } else {
            IERC20(USDC).safeTransfer(user, totalPayout);
            emit Events.PayoutClaimed(marketId, user, totalPayout);
        }
    }

    function claimRefund(uint256 marketId) external nonReentrant {
        _requireMarketExists(marketId);
        DataTypes.Market storage m = markets[marketId];

        if (m.status != uint8(DataTypes.MarketStatus.Escalated)) {
            revert Errors.MarketNotEscalated();
        }
        if (claimed[marketId][msg.sender]) revert Errors.AlreadyClaimed();

        DataTypes.UserPosition storage pos = positions[marketId][msg.sender];
        uint256 refund = _calculateRefund(pos.totalBetYes, pos.totalBetNo);

        claimed[marketId][msg.sender] = true;

        if (pos.yesShares > 0) {
            IPositionToken(POSITION_TOKEN).burn(
                msg.sender,
                marketId * 2,
                pos.yesShares
            );
        }
        if (pos.noShares > 0) {
            IPositionToken(POSITION_TOKEN).burn(
                msg.sender,
                marketId * 2 + 1,
                pos.noShares
            );
        }

        IERC20(USDC).safeTransfer(msg.sender, refund);
        emit Events.RefundProcessed(marketId, msg.sender, refund);
    }

    function withdrawFees(uint256 marketId) external nonReentrant {
        _requireMarketExists(marketId);
        DataTypes.Market storage m = markets[marketId];

        if (m.creator != msg.sender) revert Errors.Unauthorized();
        if (m.status != uint8(DataTypes.MarketStatus.Resolved)) {
            revert Errors.MarketNotResolved();
        }

        uint256 fees = accumulatedFees[marketId];
        if (fees == 0) revert Errors.NothingToClaim();

        accumulatedFees[marketId] = 0;
        IERC20(USDC).safeTransfer(msg.sender, fees);

        emit Events.FeeWithdrawn(marketId, msg.sender, fees);
    }

    /// @notice Gasless withdraw fees via meta-transaction
    function withdrawFeesWithSignature(
        uint256 marketId,
        uint256 relayerFee,
        uint256 deadline,
        bytes calldata signature
    ) external onlyRelayer nonReentrant {
        if (block.timestamp > deadline) revert Errors.DeadlineAlreadyPassed();

        bytes32 structHash = keccak256(
            abi.encode(
                WITHDRAW_FEES_TYPEHASH,
                marketId,
                msg.sender,
                relayerFee,
                nonces[tx.origin]++,
                deadline
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = _getVRS(signature);
        address user = ecrecover(hash, v, r, s);
        if (user == address(0)) revert Errors.InvalidAddress();

        _requireMarketExists(marketId);
        DataTypes.Market storage m = markets[marketId];

        if (m.creator != user) revert Errors.Unauthorized();
        if (m.status != uint8(DataTypes.MarketStatus.Resolved)) revert Errors.MarketNotResolved();

        uint256 fees = accumulatedFees[marketId];
        if (fees == 0) revert Errors.NothingToClaim();
        if (fees <= relayerFee) revert Errors.InsufficientLiquidity();

        accumulatedFees[marketId] = 0;
        IERC20(USDC).safeTransfer(user, fees - relayerFee);
        if (relayerFee > 0) {
            IERC20(USDC).safeTransfer(msg.sender, relayerFee);
        }

        emit Events.FeeWithdrawn(marketId, user, fees);
    }
}
