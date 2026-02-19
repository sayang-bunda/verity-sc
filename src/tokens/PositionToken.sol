// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Errors} from "../libraries/Errors.sol";

/// @notice ERC-1155 position token. Token ID even = YES, odd = NO
contract PositionToken is ERC1155, Ownable {
    address public verityContract;

    event VerityContractSet(address indexed verity);

    modifier onlyVerity() {
        if (msg.sender != verityContract) revert Errors.Unauthorized();
        _;
    }

    constructor() ERC1155("") Ownable(msg.sender) {}

    function setVerityContract(address _verity) external onlyOwner {
        if (_verity == address(0)) revert Errors.InvalidAddress();
        if (verityContract != address(0))
            revert Errors.VerityContractAlreadySet();
        verityContract = _verity;
        emit VerityContractSet(_verity);
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external onlyVerity {
        _mint(to, tokenId, amount, "");
    }

    function burn(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external onlyVerity {
        _burn(from, tokenId, amount);
    }

    function getYesTokenId(uint256 marketId) public pure returns (uint256) {
        return marketId * 2;
    }

    function getNoTokenId(uint256 marketId) public pure returns (uint256) {
        return marketId * 2 + 1;
    }

    function getMarketId(uint256 tokenId) public pure returns (uint256) {
        return tokenId / 2;
    }

    function isYesToken(uint256 tokenId) public pure returns (bool) {
        return tokenId % 2 == 0;
    }
}
