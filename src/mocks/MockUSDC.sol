// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract MockUSDC is ERC20, Ownable {
    // ============ Custom Errors ============
    error InvalidAddress();
    error AmountTooHigh();
    error CooldownNotExpired();
    error CooldownInvalid();

    // ============ Constants ============
    uint8 private constant DECIMALS = 6;
    uint256 internal constant MAX_MINT_AMOUNT = 1_000_000 * 10 ** DECIMALS; 
    uint256 internal constant FAUCET_AMOUNT = 1_000 * 10 ** DECIMALS;
    uint256 internal constant MIN_COOLDOWN = 1 minutes;
    uint256 internal constant MAX_COOLDOWN = 24 hours;

    // ============ State ============
    uint256 public cooldownPeriod = 1 hours;
    mapping(address => uint256) public lastFaucetClaim;

    // ============ Events ============
    event Faucet(address indexed recipient, uint256 amount);
    event CooldownUpdated(uint256 newCooldown);

    constructor(
        uint256 initialSupply
    ) ERC20("Mock USD Coin", "USDC") Ownable(msg.sender) {
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
    function faucet() external {
        if (block.timestamp < lastFaucetClaim[msg.sender] + cooldownPeriod) {
            revert CooldownNotExpired();
        }

        lastFaucetClaim[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);

        emit Faucet(msg.sender, FAUCET_AMOUNT);
    }
    function mint(address to, uint256 amount) external {
        if (to == address(0)) revert InvalidAddress();
        if (amount > MAX_MINT_AMOUNT) revert AmountTooHigh();

        _mint(to, amount);
    }
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    function setCooldownPeriod(uint256 newCooldown) external onlyOwner {
        if (newCooldown < MIN_COOLDOWN) revert CooldownInvalid();
        if (newCooldown > MAX_COOLDOWN) revert CooldownInvalid();

        cooldownPeriod = newCooldown;
        emit CooldownUpdated(newCooldown);
    }
    function getFaucetCooldown(
        address user
    ) external view returns (uint256 remainingTime) {
        uint256 nextClaim = lastFaucetClaim[user] + cooldownPeriod;
        if (block.timestamp >= nextClaim) return 0;
        return nextClaim - block.timestamp;
    }
    function canClaimFaucet(address user) external view returns (bool) {
        return block.timestamp >= lastFaucetClaim[user] + cooldownPeriod;
    }
}
