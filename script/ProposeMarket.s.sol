// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVerity {
    function proposeMarket(
        string calldata payloadJSON
    ) external returns (uint256 proposalId);
    function proposalCount() external view returns (uint256);
}

/**
 * @notice Propose a new market to get a fresh proposalId for CRE-1 simulation.
 * Requires 5 USDC approved to Verity first.
 * Env vars: PRIVATE_KEY, VERITY_ADDRESS, USDC_ADDRESS
 */
contract ProposeMarket is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address verity = vm.envAddress("VERITY_ADDRESS");
        address usdc = vm.envAddress("USDC_ADDRESS");
        address creator = vm.addr(deployerKey);

        uint256 proposalDepositAmount = 5 * 1e6; // 5 USDC (6 decimals)

        vm.startBroadcast(deployerKey);

        // Approve 5 USDC to Verity
        IERC20(usdc).approve(verity, proposalDepositAmount);

        // Propose market
        string
            memory payload = '{"question":"Will ETH reach $5000 before end of month?","category":"CRYPTO","creator":"';
        payload = string(abi.encodePacked(payload, vm.toString(creator), '"}'));

        uint256 proposalId = IVerity(verity).proposeMarket(payload);

        vm.stopBroadcast();

        console2.log("--- Proposal Created ---");
        console2.log("Creator    :", creator);
        console2.log("ProposalId :", proposalId);
        console2.log("");
        console2.log(">>> Use this proposalId in CRE-1 simulation input:");
        console2.log(
            '    {"creator":"%s","proposalId":"%s","inputType":"manual","question":"Will ETH reach $5000 before end of month?"}',
            creator,
            vm.toString(proposalId)
        );
    }
}
