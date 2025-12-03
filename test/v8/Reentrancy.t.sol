// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v8/Bank.sol";
import "../../src/attackers/ReentrancyAttacker.sol";

contract ReentrancyV8 is Test {
    Bank public bank;
    ReentrancyAttacker public attacker;

    address public victim1 = makeAddr("victim1");
    address public victim2 = makeAddr("victim2");
    address public attackerAddr = makeAddr("attacker");

    function setUp() public {
        console.log("=== SETUP ===");
        // Deploy bank
        bank = new Bank();
        console.log("  Bank deployed\n");

        // Fund victims and make deposits
        vm.deal(victim1, 5 ether);
        vm.deal(victim2, 5 ether);

        vm.prank(victim1);
        bank.deposit{ value: 5 ether }();

        vm.prank(victim2);
        bank.deposit{ value: 5 ether }();

        // Deploy attacker
        attacker = new ReentrancyAttacker(address(bank));
        vm.deal(address(attacker), 1 ether);
    }

    function test_1_ReentrancyAttack() public {
        console.log("=== REENTRANCY ATTACK DEMO ===");

        console.log("[STEP 0] Initial state");
        uint256 bankBalanceBefore = address(bank).balance;
        uint256 attackerBalanceBefore = address(attacker).balance;
        console.log("  Bank balance:", bankBalanceBefore / 1e18, "ETH");
        console.log("  Attacker balance:", attackerBalanceBefore / 1e18, "ETH\n");

        console.log("[STEP 1] Execute reentrancy attack");
        attacker.attack{ value: 1 ether }(false); // Attack vulnerable withdraw function
        console.log("  Reentrancy attack is successful\n");

        console.log("[STEP 2] Results");
        uint256 bankBalanceAfter = address(bank).balance;
        uint256 attackerBalanceAfter = address(attacker).balance;
        console.log("  Bank balance:", bankBalanceAfter / 1e18, "ETH");
        console.log("  Attacker balance:", attackerBalanceAfter / 1e18, "ETH");
        console.log("  Attacker drained:", (bankBalanceBefore - bankBalanceAfter) / 1e18, "ETH");

        // Assertions
        assertEq(bankBalanceAfter, 0, "Bank should be drained");
        assertGt(attackerBalanceAfter, attackerBalanceBefore, "Attacker should profit");
    }

    function test_2_SafeReentrancy() public {
        console.log("=== REENTRANCY ATTACK MIGITATION ===");

        console.log("[STEP 0] Initial state");
        uint256 bankBalanceBefore = address(bank).balance;
        uint256 attackerBalanceBefore = address(attacker).balance;
        console.log("  Bank balance", bankBalanceBefore / 1e18, "ETH");
        console.log("  Attacker balance", attackerBalanceBefore / 1e18, "ETH\n");

        console.log("[STEP 1] Execute reentrancy attack");
        vm.expectRevert(); // Expect revert due to reentrancy guard
        attacker.attack{ value: 1 ether }(true); // Attack safe withdraw function
        console.log("  Reentrancy attack refused\n");

        console.log("[STEP 2] Results");
        uint256 bankBalanceAfter = address(bank).balance;
        uint256 attackerBalanceAfter = address(attacker).balance;

        console.log("  Bank balance:", bankBalanceAfter / 1e18, "ETH");
        console.log("  Attacker balance:", attackerBalanceAfter / 1e18, "ETH");
        console.log("  Attacker drained:", (bankBalanceBefore - bankBalanceAfter) / 1e18, "ETH");

        // Assertions
        assertEq(bankBalanceAfter - bankBalanceBefore, 0, "Bank should be intact");
        assertEq(attackerBalanceAfter, attackerBalanceBefore, "Attacker should not profit");
    }
}
