// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {Verity} from "../src/Verity.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {PositionToken} from "../src/tokens/PositionToken.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Errors} from "../src/libraries/Errors.sol";

contract VerityTest is Test {
    Verity public verity;
    MockUSDC public usdc;
    PositionToken public posToken;

    address public admin = makeAddr("admin");
    address public cre = makeAddr("cre");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    uint256 constant INITIAL_MINT = 100_000 * 1e6;
    uint128 constant SEED_AMOUNT = 10_000 * 1e6;
    uint256 constant BET_AMOUNT = 1_000 * 1e6;
    uint16 constant FEE_BPS = 200;
    uint8 constant CATEGORY_CRYPTO = 0;
    uint64 constant DEADLINE_OFFSET = 7 days;

    uint256 public marketId;

    function setUp() public {
        usdc = new MockUSDC(0);
        posToken = new PositionToken();
        verity = new Verity(address(usdc), address(posToken), admin, cre);

        posToken.setVerityContract(address(verity));

        usdc.mint(alice, INITIAL_MINT);
        usdc.mint(bob, INITIAL_MINT);
        usdc.mint(charlie, INITIAL_MINT);

        vm.prank(alice);
        usdc.approve(address(verity), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(verity), type(uint256).max);
        vm.prank(charlie);
        usdc.approve(address(verity), type(uint256).max);
    }

    // ============ Helpers ============

    function _createMarket() internal returns (uint256 id) {
        vm.prank(cre);
        id = verity.createMarketFromCre(
            alice,
            uint64(block.timestamp + DEADLINE_OFFSET),
            FEE_BPS,
            CATEGORY_CRYPTO,
            "Will BTC reach $100k by end of 2025?",
            "Resolved Yes if BTC price >= $100,000 USD on any major exchange",
            "Chainlink BTC/USD, CoinGecko"
        );
    }

    function _seedMarket(uint256 id) internal {
        vm.prank(alice);
        verity.seedLiquidity(id, SEED_AMOUNT, SEED_AMOUNT);
    }

    function _placeBet(
        address user,
        uint256 id,
        bool isYes,
        uint256 amount
    ) internal {
        vm.prank(user);
        verity.placeBet(id, amount, isYes, 0);
    }

    // ============ TC-01 ~ TC-02: Deploy ============

    function test_TC01_DeploySuccess() public view {
        assertEq(verity.usdc(), address(usdc));
        assertEq(verity.positionToken(), address(posToken));
        assertEq(verity.marketCount(), 0);
        assertTrue(verity.hasRole(verity.ADMIN_ROLE(), admin));
        assertTrue(verity.hasRole(verity.CRE_ROLE(), cre));
    }

    function test_TC02_PositionTokenLinked() public view {
        assertEq(posToken.verityContract(), address(verity));
    }

    // ============ TC-03 ~ TC-06: Create Market ============

    function test_TC03_CRECanCreateMarket() public {
        marketId = _createMarket();
        assertEq(verity.marketCount(), 1);

        DataTypes.Market memory m = verity.getMarket(marketId);
        assertEq(m.creator, alice);
        assertEq(m.feeBps, FEE_BPS);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Active));
        assertEq(m.outcome, uint8(DataTypes.MarketOutcome.Unresolved));
        assertEq(m.category, CATEGORY_CRYPTO);
    }

    function test_TC04_NonCRECannotCreateMarket() public {
        vm.prank(alice);
        vm.expectRevert(Errors.Unauthorized.selector);
        verity.createMarketFromCre(
            alice,
            uint64(block.timestamp + DEADLINE_OFFSET),
            FEE_BPS,
            CATEGORY_CRYPTO,
            "Test?",
            "Criteria",
            "Sources"
        );
    }

    function test_TC05_PastDeadlineReverts() public {
        vm.prank(cre);
        vm.expectRevert(Errors.DeadlineAlreadyPassed.selector);
        verity.createMarketFromCre(
            alice,
            uint64(block.timestamp - 1),
            FEE_BPS,
            CATEGORY_CRYPTO,
            "Test?",
            "Criteria",
            "Sources"
        );
    }

    function test_TC06_FeeTooHighReverts() public {
        vm.prank(cre);
        vm.expectRevert(Errors.InvalidFeeBps.selector);
        verity.createMarketFromCre(
            alice,
            uint64(block.timestamp + DEADLINE_OFFSET),
            1001,
            CATEGORY_CRYPTO,
            "Test?",
            "Criteria",
            "Sources"
        );
    }

    // ============ TC-07 ~ TC-09: Seed Liquidity ============

    function test_TC07_CreatorCanSeed() public {
        marketId = _createMarket();
        _seedMarket(marketId);

        DataTypes.Market memory m = verity.getMarket(marketId);
        assertEq(m.poolYes, SEED_AMOUNT);
        assertEq(m.poolNo, SEED_AMOUNT);
        assertTrue(verity.isSeeded(marketId));
    }

    function test_TC08_NonCreatorCannotSeed() public {
        marketId = _createMarket();
        vm.prank(bob);
        vm.expectRevert(Errors.Unauthorized.selector);
        verity.seedLiquidity(marketId, SEED_AMOUNT, SEED_AMOUNT);
    }

    function test_TC09_CannotSeedTwice() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        vm.prank(alice);
        vm.expectRevert(Errors.AlreadySeeded.selector);
        verity.seedLiquidity(marketId, SEED_AMOUNT, SEED_AMOUNT);
    }

    // ============ TC-10 ~ TC-15: Place Bet ============

    function test_TC10_BobCanBetYes() public {
        marketId = _createMarket();
        _seedMarket(marketId);

        uint256 balBefore = usdc.balanceOf(bob);
        _placeBet(bob, marketId, true, BET_AMOUNT);

        DataTypes.UserPosition memory pos = verity.getPosition(marketId, bob);
        assertGt(pos.yesShares, 0);
        assertEq(pos.totalBetYes, uint128(BET_AMOUNT));
        assertLt(usdc.balanceOf(bob), balBefore);
    }

    function test_TC11_BobCanBetNo() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        _placeBet(bob, marketId, false, BET_AMOUNT);
        assertGt(verity.getPosition(marketId, bob).noShares, 0);
    }

    function test_TC12_BetBeforeSeedReverts() public {
        marketId = _createMarket();
        vm.prank(bob);
        vm.expectRevert(Errors.InsufficientLiquidity.selector);
        verity.placeBet(marketId, BET_AMOUNT, true, 0);
    }

    function test_TC13_BetAfterDeadlineReverts() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        vm.warp(block.timestamp + DEADLINE_OFFSET + 1);
        vm.prank(bob);
        vm.expectRevert(Errors.DeadlineAlreadyPassed.selector);
        verity.placeBet(marketId, BET_AMOUNT, true, 0);
    }

    function test_TC14_SlippageProtection() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        vm.prank(bob);
        vm.expectRevert(Errors.SlippageExceeded.selector);
        verity.placeBet(marketId, BET_AMOUNT, true, type(uint256).max);
    }

    function test_TC15_FeesAccumulated() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        _placeBet(bob, marketId, true, BET_AMOUNT);

        uint256 expectedFee = (BET_AMOUNT * FEE_BPS) / 10_000;
        assertGe(verity.getAccumulatedFees(marketId), expectedFee);
    }

    // ============ TC-16 ~ TC-20: Manipulation & Risk ============

    function test_TC16_ReportManipulationPauses() public {
        marketId = _createMarket();
        vm.prank(cre);
        verity.reportManipulation(marketId, 75, "Suspicious wash trading");

        DataTypes.Market memory m = verity.getMarket(marketId);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Paused));
        assertEq(m.manipulationScore, 75);
    }

    function test_TC17_LowScoreNoAction() public {
        marketId = _createMarket();
        vm.prank(cre);
        verity.reportManipulation(marketId, 50, "Minor anomaly");

        assertEq(
            verity.getMarket(marketId).status,
            uint8(DataTypes.MarketStatus.Active)
        );
    }

    function test_TC18_AdminCanUnpause() public {
        marketId = _createMarket();
        vm.prank(cre);
        verity.reportManipulation(marketId, 80, "Manipulation");
        vm.prank(admin);
        verity.unpauseMarket(marketId);

        DataTypes.Market memory m = verity.getMarket(marketId);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Active));
        assertEq(m.manipulationScore, 0);
    }

    function test_TC19_NonAdminCannotUnpause() public {
        marketId = _createMarket();
        vm.prank(cre);
        verity.reportManipulation(marketId, 80, "Manipulation");
        vm.prank(bob);
        vm.expectRevert(Errors.Unauthorized.selector);
        verity.unpauseMarket(marketId);
    }

    function test_TC20_BetOnPausedMarketReverts() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        vm.prank(cre);
        verity.reportManipulation(marketId, 80, "Manipulation");
        vm.prank(bob);
        vm.expectRevert(Errors.MarketNotActive.selector);
        verity.placeBet(marketId, BET_AMOUNT, true, 0);
    }

    // ============ TC-21 ~ TC-23: Resolve Market ============

    function test_TC21_ResolveHighConfidence() public {
        marketId = _createMarket();
        vm.prank(cre);
        verity.resolveMarketFromCre(
            marketId,
            uint8(DataTypes.MarketOutcome.Yes),
            95
        );

        DataTypes.Market memory m = verity.getMarket(marketId);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Resolved));
        assertEq(m.outcome, uint8(DataTypes.MarketOutcome.Yes));
    }

    function test_TC22_EscalateLowConfidence() public {
        marketId = _createMarket();
        vm.prank(cre);
        verity.resolveMarketFromCre(
            marketId,
            uint8(DataTypes.MarketOutcome.No),
            70
        );

        DataTypes.Market memory m = verity.getMarket(marketId);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Escalated));
        assertEq(m.outcome, uint8(DataTypes.MarketOutcome.Unresolved));
    }

    function test_TC23_CannotReResolve() public {
        marketId = _createMarket();
        vm.startPrank(cre);
        verity.resolveMarketFromCre(
            marketId,
            uint8(DataTypes.MarketOutcome.Yes),
            95
        );
        vm.expectRevert(Errors.MarketAlreadyResolved.selector);
        verity.resolveMarketFromCre(
            marketId,
            uint8(DataTypes.MarketOutcome.No),
            95
        );
        vm.stopPrank();
    }

    // ============ TC-24 ~ TC-26: Claim Payout ============

    function test_TC24_WinnerCanClaim() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        _placeBet(bob, marketId, true, BET_AMOUNT);

        vm.prank(cre);
        verity.resolveMarketFromCre(
            marketId,
            uint8(DataTypes.MarketOutcome.Yes),
            95
        );

        uint256 balBefore = usdc.balanceOf(bob);
        vm.prank(bob);
        verity.claimPayout(marketId);

        assertGt(usdc.balanceOf(bob), balBefore);
        assertTrue(verity.isClaimed(marketId, bob));
    }

    function test_TC25_LoserGetsNoPayout() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        _placeBet(charlie, marketId, false, BET_AMOUNT);

        vm.prank(cre);
        verity.resolveMarketFromCre(
            marketId,
            uint8(DataTypes.MarketOutcome.Yes),
            95
        );

        vm.prank(charlie);
        vm.expectRevert(Errors.NothingToClaim.selector);
        verity.claimPayout(marketId);
    }

    function test_TC26_CannotClaimTwice() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        _placeBet(bob, marketId, true, BET_AMOUNT);

        vm.prank(cre);
        verity.resolveMarketFromCre(
            marketId,
            uint8(DataTypes.MarketOutcome.Yes),
            95
        );

        vm.startPrank(bob);
        verity.claimPayout(marketId);
        vm.expectRevert(Errors.AlreadyClaimed.selector);
        verity.claimPayout(marketId);
        vm.stopPrank();
    }

    // ============ TC-27: Claim Refund ============

    function test_TC27_RefundOnEscalated() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        _placeBet(bob, marketId, true, BET_AMOUNT);

        vm.prank(cre);
        verity.resolveMarketFromCre(
            marketId,
            uint8(DataTypes.MarketOutcome.Yes),
            70
        );

        uint256 balBefore = usdc.balanceOf(bob);
        vm.prank(bob);
        verity.claimRefund(marketId);

        assertGt(usdc.balanceOf(bob), balBefore);
    }

    // ============ TC-28 ~ TC-29: Withdraw Fees ============

    function test_TC28_CreatorCanWithdrawFees() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        _placeBet(bob, marketId, true, BET_AMOUNT);

        uint256 fees = verity.getAccumulatedFees(marketId);
        uint256 balBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        verity.withdrawFees(marketId);

        assertEq(usdc.balanceOf(alice), balBefore + fees);
        assertEq(verity.getAccumulatedFees(marketId), 0);
    }

    function test_TC29_NonCreatorCannotWithdrawFees() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        _placeBet(bob, marketId, true, BET_AMOUNT);

        vm.prank(bob);
        vm.expectRevert(Errors.Unauthorized.selector);
        verity.withdrawFees(marketId);
    }

    // ============ TC-30: Full Flow ============

    function test_TC30_FullFlow() public {
        marketId = _createMarket();
        _seedMarket(marketId);
        _placeBet(bob, marketId, true, BET_AMOUNT);
        _placeBet(charlie, marketId, false, BET_AMOUNT);

        vm.prank(cre);
        verity.resolveMarketFromCre(
            marketId,
            uint8(DataTypes.MarketOutcome.Yes),
            95
        );

        assertEq(
            verity.getMarket(marketId).status,
            uint8(DataTypes.MarketStatus.Resolved)
        );

        uint256 bobBefore = usdc.balanceOf(bob);
        uint256 aliceBefore = usdc.balanceOf(alice);

        vm.prank(bob);
        verity.claimPayout(marketId);
        vm.prank(alice);
        verity.withdrawFees(marketId);

        assertGt(usdc.balanceOf(bob), bobBefore);
        assertGt(usdc.balanceOf(alice), aliceBefore);

        console2.log("Bob payout :", usdc.balanceOf(bob) - bobBefore);
        console2.log("Alice fees :", usdc.balanceOf(alice) - aliceBefore);
    }
}
