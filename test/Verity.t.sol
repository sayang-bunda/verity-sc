// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Verity} from "../src/core/Verity.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {PositionToken} from "../src/tokens/PositionToken.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Errors} from "../src/libraries/Errors.sol";

contract VerityTest is Test {
    Verity public market;
    MockUSDC public usdc;
    PositionToken public posToken;

    address admin = makeAddr("admin");
    address cre = makeAddr("cre");
    address creator = makeAddr("creator");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant SEED_AMOUNT = 10_000e6;
    uint256 constant BET_AMOUNT = 100e6;

    function setUp() public {
        usdc = new MockUSDC(0);
        posToken = new PositionToken();

        market = new Verity(address(usdc), address(posToken), admin, cre);

        posToken.setMarketContract(address(market));

        usdc.mint(creator, SEED_AMOUNT);
        usdc.mint(alice, 10_000e6);
        usdc.mint(bob, 10_000e6);

        vm.prank(creator);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(alice);
        usdc.approve(address(market), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(market), type(uint256).max);
    }

    function _createMarket() internal returns (uint256 marketId) {
        vm.prank(cre);
        marketId = market.createMarketFromCre(
            creator,
            uint64(block.timestamp + 1 days),
            500,
            uint8(DataTypes.MarketCategory.CryptoPrice),
            "Will BTC reach 100k by end of 2026?",
            "BTC price >= 100000 USD on CoinGecko",
            "coingecko.com, coinmarketcap.com"
        );
    }

    function _createAndSeed() internal returns (uint256 marketId) {
        marketId = _createMarket();
        vm.prank(creator);
        market.seedLiquidity(marketId, SEED_AMOUNT);
    }

    // ============ DEPLOY ============

    function test_Deploy() public view {
        assertEq(market.usdc(), address(usdc));
        assertEq(market.positionToken(), address(posToken));
        assertEq(market.marketCount(), 0);
    }

    function test_RevertDeploy_ZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new Verity(address(0), address(posToken), admin, cre);
    }

    // ============ CREATE MARKET ============

    function test_CreateMarket() public {
        uint256 id = _createMarket();
        assertEq(id, 0);
        assertEq(market.marketCount(), 1);

        DataTypes.Market memory m = market.getMarket(id);
        assertEq(m.creator, creator);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Active));
        assertEq(m.outcome, uint8(DataTypes.MarketOutcome.Unresolved));
    }

    function test_RevertCreateMarket_NotCRE() public {
        vm.prank(alice);
        vm.expectRevert(Errors.Unauthorized.selector);
        market.createMarketFromCre(
            creator,
            uint64(block.timestamp + 1 days),
            500,
            0,
            "q",
            "c",
            "s"
        );
    }

    // ============ SEED LIQUIDITY ============

    function test_SeedLiquidity() public {
        uint256 id = _createMarket();

        vm.prank(creator);
        market.seedLiquidity(id, SEED_AMOUNT);

        assertTrue(market.isSeeded(id));
        DataTypes.Market memory m = market.getMarket(id);
        assertEq(m.poolYes, SEED_AMOUNT / 2);
        assertEq(m.poolNo, SEED_AMOUNT / 2);
    }

    function test_RevertSeed_NotCreator() public {
        uint256 id = _createMarket();
        vm.prank(alice);
        vm.expectRevert(Errors.Unauthorized.selector);
        market.seedLiquidity(id, SEED_AMOUNT);
    }

    function test_RevertSeed_AlreadySeeded() public {
        uint256 id = _createAndSeed();
        vm.prank(creator);
        vm.expectRevert(Errors.AlreadySeeded.selector);
        market.seedLiquidity(id, SEED_AMOUNT);
    }

    // ============ PLACE BET ============

    function test_PlaceBetYes() public {
        uint256 id = _createAndSeed();

        vm.prank(alice);
        market.placeBet(id, BET_AMOUNT, true, 0);

        DataTypes.UserPosition memory pos = market.getPosition(id, alice);
        assertTrue(pos.yesShares > 0);
        assertEq(uint256(pos.totalBetYes), BET_AMOUNT);

        uint256 yesTokenId = id * 2;
        assertTrue(posToken.balanceOf(alice, yesTokenId) > 0);
    }

    function test_PlaceBetNo() public {
        uint256 id = _createAndSeed();

        vm.prank(bob);
        market.placeBet(id, BET_AMOUNT, false, 0);

        DataTypes.UserPosition memory pos = market.getPosition(id, bob);
        assertTrue(pos.noShares > 0);
        assertEq(uint256(pos.totalBetNo), BET_AMOUNT);
    }

    function test_RevertBet_NotSeeded() public {
        uint256 id = _createMarket();
        vm.prank(alice);
        vm.expectRevert(Errors.InsufficientLiquidity.selector);
        market.placeBet(id, BET_AMOUNT, true, 0);
    }

    function test_RevertBet_AfterDeadline() public {
        uint256 id = _createAndSeed();
        vm.warp(block.timestamp + 2 days);
        vm.prank(alice);
        vm.expectRevert(Errors.DeadlineAlreadyPassed.selector);
        market.placeBet(id, BET_AMOUNT, true, 0);
    }

    function test_RevertBet_SlippageExceeded() public {
        uint256 id = _createAndSeed();
        vm.prank(alice);
        vm.expectRevert(Errors.SlippageExceeded.selector);
        market.placeBet(id, BET_AMOUNT, true, type(uint256).max);
    }

    // ============ MANIPULATION + PAUSE ============

    function test_ReportManipulation_Pause() public {
        uint256 id = _createAndSeed();

        vm.prank(cre);
        market.reportManipulation(id, 80, "Suspicious volume spike");

        DataTypes.Market memory m = market.getMarket(id);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Paused));
        assertEq(m.manipulationScore, 80);
    }

    function test_ReportManipulation_NoPause() public {
        uint256 id = _createAndSeed();

        vm.prank(cre);
        market.reportManipulation(id, 50, "Minor anomaly");

        DataTypes.Market memory m = market.getMarket(id);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Active));
        assertEq(m.manipulationScore, 50);
    }

    function test_UnpauseMarket() public {
        uint256 id = _createAndSeed();

        vm.prank(cre);
        market.reportManipulation(id, 80, "Suspicious");

        vm.prank(admin);
        market.unpauseMarket(id);

        DataTypes.Market memory m = market.getMarket(id);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Active));
        assertEq(m.manipulationScore, 0);
    }

    // ============ RESOLVE MARKET ============

    function test_ResolveMarket_Yes() public {
        uint256 id = _createAndSeed();

        vm.warp(block.timestamp + 2 days);

        vm.prank(cre);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 95);

        DataTypes.Market memory m = market.getMarket(id);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Resolved));
        assertEq(m.outcome, uint8(DataTypes.MarketOutcome.Yes));
    }

    function test_ResolveMarket_Escalated() public {
        uint256 id = _createAndSeed();

        vm.warp(block.timestamp + 2 days);

        vm.prank(cre);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 50);

        DataTypes.Market memory m = market.getMarket(id);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Escalated));
    }

    function test_RevertResolve_BeforeDeadline() public {
        uint256 id = _createAndSeed();

        vm.prank(cre);
        vm.expectRevert(Errors.DeadlineNotReached.selector);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 95);
    }

    // ============ CLAIM PAYOUT ============

    function test_ClaimPayout_YesWins() public {
        uint256 id = _createAndSeed();

        vm.prank(alice);
        market.placeBet(id, BET_AMOUNT, true, 0);

        vm.prank(bob);
        market.placeBet(id, BET_AMOUNT, false, 0);

        vm.warp(block.timestamp + 2 days);
        vm.prank(cre);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 95);

        uint256 balanceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        market.claimPayout(id);

        uint256 balanceAfter = usdc.balanceOf(alice);
        assertTrue(balanceAfter > balanceBefore);
        assertTrue(market.isClaimed(id, alice));
    }

    function test_RevertClaim_DoubleClaim() public {
        uint256 id = _createAndSeed();

        vm.prank(alice);
        market.placeBet(id, BET_AMOUNT, true, 0);

        vm.warp(block.timestamp + 2 days);
        vm.prank(cre);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 95);

        vm.prank(alice);
        market.claimPayout(id);

        vm.prank(alice);
        vm.expectRevert(Errors.AlreadyClaimed.selector);
        market.claimPayout(id);
    }

    function test_RevertClaim_NotResolved() public {
        uint256 id = _createAndSeed();

        vm.prank(alice);
        market.placeBet(id, BET_AMOUNT, true, 0);

        vm.prank(alice);
        vm.expectRevert(Errors.MarketNotResolved.selector);
        market.claimPayout(id);
    }

    // ============ CLAIM REFUND ============

    function test_ClaimRefund() public {
        uint256 id = _createAndSeed();

        vm.prank(alice);
        market.placeBet(id, BET_AMOUNT, true, 0);

        vm.warp(block.timestamp + 2 days);
        vm.prank(cre);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 50);

        DataTypes.Market memory m = market.getMarket(id);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Escalated));

        uint256 balanceBefore = usdc.balanceOf(alice);

        vm.prank(alice);
        market.claimRefund(id);

        uint256 balanceAfter = usdc.balanceOf(alice);
        assertEq(balanceAfter - balanceBefore, BET_AMOUNT);
    }

    // ============ WITHDRAW FEES ============

    function test_WithdrawFees() public {
        uint256 id = _createAndSeed();

        vm.prank(alice);
        market.placeBet(id, BET_AMOUNT, true, 0);

        vm.warp(block.timestamp + 2 days);
        vm.prank(cre);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 95);

        uint256 fees = market.getAccumulatedFees(id);
        assertTrue(fees > 0);

        uint256 balanceBefore = usdc.balanceOf(creator);

        vm.prank(creator);
        market.withdrawFees(id);

        uint256 balanceAfter = usdc.balanceOf(creator);
        assertEq(balanceAfter - balanceBefore, fees);
        assertEq(market.getAccumulatedFees(id), 0);
    }

    function test_RevertWithdrawFees_NotCreator() public {
        uint256 id = _createAndSeed();

        vm.prank(alice);
        market.placeBet(id, BET_AMOUNT, true, 0);

        vm.warp(block.timestamp + 2 days);
        vm.prank(cre);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 95);

        vm.prank(alice);
        vm.expectRevert(Errors.Unauthorized.selector);
        market.withdrawFees(id);
    }

    // ============ FULL FLOW ============

    function test_FullFlow() public {
        uint256 id = _createMarket();

        vm.prank(creator);
        market.seedLiquidity(id, SEED_AMOUNT);

        vm.prank(alice);
        market.placeBet(id, 500e6, true, 0);

        vm.prank(bob);
        market.placeBet(id, 300e6, false, 0);

        vm.prank(cre);
        market.reportManipulation(id, 30, "Low risk");

        vm.warp(block.timestamp + 2 days);

        vm.prank(cre);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 95);

        uint256 aliceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        market.claimPayout(id);
        uint256 aliceAfter = usdc.balanceOf(alice);
        assertTrue(aliceAfter > aliceBefore);

        vm.prank(creator);
        market.withdrawFees(id);

        DataTypes.Market memory m = market.getMarket(id);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Resolved));
        assertTrue(m.totalVolume > 0);
    }

    // ============ ADDITIONAL COVERAGE (PDF BLUEPRINT) ============

    function test_RevertBet_MarketPaused() public {
        uint256 id = _createAndSeed();

        vm.prank(cre);
        market.reportManipulation(id, 80, "Whale activity detected");

        DataTypes.Market memory m = market.getMarket(id);
        assertEq(m.status, uint8(DataTypes.MarketStatus.Paused));

        vm.prank(alice);
        vm.expectRevert(Errors.MarketNotActive.selector);
        market.placeBet(id, BET_AMOUNT, true, 0);
    }

    function test_RevertClaim_LoserGetsNothing() public {
        uint256 id = _createAndSeed();

        vm.prank(alice);
        market.placeBet(id, BET_AMOUNT, false, 0);

        vm.warp(block.timestamp + 2 days);
        vm.prank(cre);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 95);

        vm.prank(alice);
        vm.expectRevert(Errors.NothingToClaim.selector);
        market.claimPayout(id);
    }

    function test_RevertReportManipulation_NotCRE() public {
        uint256 id = _createAndSeed();

        vm.prank(alice);
        vm.expectRevert(Errors.Unauthorized.selector);
        market.reportManipulation(id, 80, "Fake report");
    }

    function test_RevertResolve_NotCRE() public {
        uint256 id = _createAndSeed();

        vm.warp(block.timestamp + 2 days);

        vm.prank(alice);
        vm.expectRevert(Errors.Unauthorized.selector);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 95);
    }

    function test_MultipleBettors_CorrectPayout() public {
        uint256 id = _createAndSeed();

        vm.prank(alice);
        market.placeBet(id, 500e6, true, 0);

        vm.prank(bob);
        market.placeBet(id, 300e6, false, 0);

        vm.warp(block.timestamp + 2 days);
        vm.prank(cre);
        market.resolveMarketFromCre(id, uint8(DataTypes.MarketOutcome.Yes), 95);

        uint256 aliceBefore = usdc.balanceOf(alice);
        vm.prank(alice);
        market.claimPayout(id);
        uint256 aliceAfter = usdc.balanceOf(alice);
        uint256 alicePayout = aliceAfter - aliceBefore;

        assertTrue(alicePayout > 500e6, "Winner should profit more than bet");

        vm.prank(bob);
        vm.expectRevert(Errors.NothingToClaim.selector);
        market.claimPayout(id);
    }
}
