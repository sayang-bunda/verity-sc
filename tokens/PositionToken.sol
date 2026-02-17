// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PositionToken is ERC1155, Ownable {
    error Unauthorized();

    address public safeMarket;

    event SafeMarketUpdated(address indexed newSafeMarket);

    constructor() ERC1155("") Ownable(msg.sender) {}

    modifier onlySafeMarket() {
        if (msg.sender != safeMarket) revert Unauthorized();
        _;
    }

    function setSafeMarket(address _safeMarket) external onlyOwner {
        if (_safeMarket == address(0)) revert Unauthorized();
        safeMarket = _safeMarket;
        emit SafeMarketUpdated(_safeMarket);
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external onlySafeMarket {
        _mint(to, tokenId, amount, "");
    }

    function burn(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external onlySafeMarket {
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
