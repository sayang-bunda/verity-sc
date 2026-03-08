// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IMockForwarderV2 {
    function report(
        address receiver,
        bytes calldata rawReport,
        bytes calldata reportContext,
        bytes[] calldata signatures
    ) external;
}

/**
 * @notice Manually call MockForwarderV2.report() with valid ABI payload.
 * Tests if MockForwarderV2 → Verity path works when called with correct bytes.
 * If this succeeds but CRE CLI fails → issue is in CRE SDK report encoding.
 *
 * Run: forge script script/TestMockForwarder.s.sol --rpc-url https://sepolia.base.org --broadcast
 */
contract TestMockForwarder is Script {
    // Addresses
    address constant MOCK_FORWARDER_V2 =
        0x9c8094090357e19449036dCD9F747001e8DC2394;
    address constant VERITY = 0x357E246B17bEF83BE4eA3321cBCA1BB642D17150;

    uint8 constant ACTION_CREATE_MARKET = 1;
    uint16 constant FEE_BPS = 200;
    uint8 constant CATEGORY_CRYPTO = 0;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address creator = vm.envAddress("ADMIN_ADDRESS");

        // Build the exact same payload that CRE-1 market.ts generates
        // proposalId = 15, deadline = 30 days from now
        uint256 proposalId = 15;
        uint64 deadline = uint64(block.timestamp + 30 days);
        int256 targetValue = 500000000000; // $5000 * 1e8
        address priceFeed = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
        uint8 riskScore = 20;

        bytes memory rawReport = abi.encode(
            ACTION_CREATE_MARKET,
            proposalId,
            creator,
            deadline,
            FEE_BPS,
            CATEGORY_CRYPTO,
            "Will ETH reach $5000 before end of month?",
            "Resolves YES if ETH price reaches $5000 on any major exchange.",
            '["coinbase.com","binance.com"]',
            targetValue,
            priceFeed,
            riskScore
        );

        // reportContext = metadata (typically 32-byte workflow ID, rest zeros)
        bytes memory reportContext = abi.encodePacked(bytes32(0));

        bytes[] memory signatures = new bytes[](0);

        console2.log("MockForwarderV2 :", MOCK_FORWARDER_V2);
        console2.log("Verity (receiver):", VERITY);
        console2.log("ProposalId       :", proposalId);
        console2.log("Deadline         :", deadline);
        console2.log("RawReport length :", rawReport.length);

        vm.startBroadcast(deployerKey);
        IMockForwarderV2(MOCK_FORWARDER_V2).report(
            VERITY,
            rawReport,
            reportContext,
            signatures
        );
        vm.stopBroadcast();

        console2.log("SUCCESS - Market created via MockForwarderV2!");
    }
}
