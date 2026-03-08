// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title GrantCRERole
 * @notice Grant CRE_ROLE ke satu alamat di Verity.
 *
 * Cara menjalankan:
 *   VERITY_ADDRESS=0x... GRANTEE=0x... \
 *   forge script script/GrantCRERole.s.sol \
 *     --rpc-url https://sepolia.base.org --broadcast
 */
contract GrantCRERole is Script {
    bytes32 constant CRE_ROLE = keccak256("CRE_ROLE");

    function run() external {
        uint256 adminKey = vm.envUint("PRIVATE_KEY");
        address verity  = vm.envAddress("VERITY_ADDRESS");
        address grantee = vm.envAddress("GRANTEE");

        vm.startBroadcast(adminKey);
        IAccessControl(verity).grantRole(CRE_ROLE, grantee);
        vm.stopBroadcast();

        console2.log("CRE_ROLE granted on Verity:", verity);
        console2.log("Grantee                   :", grantee);
    }
}
