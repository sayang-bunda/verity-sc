// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PositionToken is ERC1155, Ownable {
    error Unauthorized();
    error InvalidAddress();
    error MarketContractAlreadySet();

    address public marketContract;

    event MarketContractUpdated(address indexed newMarketContract);

    modifier onlyMarketContract() {
        _onlyMarketContract();
        _;
    }

    function _onlyMarketContract() internal view {
        if (msg.sender != marketContract) revert Unauthorized();
    }

    constructor() ERC1155("") Ownable(msg.sender) {}

    function setMarketContract(address _marketContract) external onlyOwner {
        if (_marketContract == address(0)) revert InvalidAddress();
        if (marketContract != address(0)) revert MarketContractAlreadySet();
        marketContract = _marketContract;
        emit MarketContractUpdated(_marketContract);
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external onlyMarketContract {
        _mint(to, tokenId, amount, "");
    }

    function burn(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external onlyMarketContract {
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
