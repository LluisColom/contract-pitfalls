// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";

contract Vault {
    // ============ State Variables ============
    address public immutable owner;

    // ============ Events ============
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    // ============ Errors ============
    error NotOwner();
    error EmptyDeposit();
    error InsufficientBalance();
    error TransferFailed();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    // ============ Constructor ============
    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Deposites ETH to the vault
     */
    function deposit() external payable {
        if (msg.value == 0) revert EmptyDeposit();
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw your deposited ETH
     * @dev VULNERABILITY: No access control
     */
    function unsafe_withdraw() external {
        uint256 amount = address(this).balance;
        if (amount == 0) revert InsufficientBalance();

        // msg.sender can be anyone (should use owner instead)
        (bool success,) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @notice Withdraw your deposited ETH
     * @dev ACCES CONTROL: Only the owner can withdraw
     */
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        if (amount == 0) revert InsufficientBalance();

        (bool success,) = payable(owner).call{ value: amount }("");
        if (!success) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    // ============ View Functions ============

    // Returns how much ETH is in the vault
    function balance() external view returns (uint256) {
        return address(this).balance;
    }

    // ============ Fallback ============

    receive() external payable { }
}
