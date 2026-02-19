// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Errors} from "../libraries/Errors.sol";

abstract contract AccessManager is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CRE_ROLE = keccak256("CRE_ROLE");

    modifier onlyAdmin() {
        _checkAdmin();
        _;
    }

    modifier onlyCre() {
        _checkCre();
        _;
    }

    function _checkAdmin() internal view {
        if (!hasRole(ADMIN_ROLE, msg.sender)) revert Errors.Unauthorized();
    }

    function _checkCre() internal view {
        if (!hasRole(CRE_ROLE, msg.sender)) revert Errors.Unauthorized();
    }

    function _setupRoles(address admin, address cre) internal {
        if (admin == address(0) || cre == address(0)) {
            revert Errors.ZeroAddress();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(CRE_ROLE, cre);
    }
}
