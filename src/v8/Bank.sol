// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";

contract Bank {
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    function deposit() public payable {
        // Increase balance
        balances[msg.sender] += msg.value;
        // Emit log
        emit Deposit(msg.sender, msg.value);
    }

    function unsafe_withdraw(uint256 _amount) public {
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        // VULNERABILITY: External call before state update
        (bool success,) = msg.sender.call{ value: _amount }("");
        require(success, "Transfer failed");
        // SAVE GAS BY USING UNCHECKED BLOCK (DANGEROUS!!!)
        unchecked {
            // Bypasses this check
            // if (balances[msg.sender] < _amount) {
            //     revert Panic(0x11); // Arithmetic underflow
            // }

            // Decrease balance
            balances[msg.sender] -= _amount;
        }
        // Emit log
        emit Withdrawal(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public {
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        // CEI Pattern: Update state before external call
        balances[msg.sender] -= _amount;

        (bool success,) = msg.sender.call{ value: _amount }("");
        require(success, "Transfer failed");

        // Emit log
        emit Withdrawal(msg.sender, _amount);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

