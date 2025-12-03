// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Vault.sol";

contract AccessControl is Test {
    Vault vault;
    address victim;
    address attacker;
    uint256 constant DEPOSIT_AMOUNT = 10 ether;

    function setUp() public {
        console.log("=== SETUP ===");
        victim = makeAddr("victim");
        attacker = makeAddr("attacker");

        // Deploy vault as victim
        vm.startPrank(victim);
        vault = new Vault();
        console.log("  Vault deployed\n");

        // Victim deposits ETH into the vault
        vm.deal(victim, 10 ether);
        vault.deposit{ value: 10 ether }();
        vm.stopPrank();
    }

    function test_1_AccessControlAttack() public {
        console.log("=== ACCESS CONTROL ATTACK DEMO ===");

        console.log("[STEP 0] Initial state");
        uint256 balanceBefore = attacker.balance;
        console.log("  Vault balance:", vault.balance() / 1e18, "ETH");
        console.log("  Attacker balance:", balanceBefore / 1e18, "ETH\n");

        console.log("[STEP 1] Execute access control attack");
        vm.startPrank(attacker);
        // Attacker drains the vault
        vault.unsafe_withdraw();
        vm.stopPrank();
        console.log("  Access control attack is successful\n");

        console.log("[STEP 2] Results");
        uint256 balanceAfter = attacker.balance;
        console.log("Vault balance:", vault.balance() / 1e18, "ETH");
        console.log("Attacker balance:", balanceAfter / 1e18, "ETH");

        assertGt(balanceAfter, balanceBefore);
        assertEq(address(vault).balance, 0); // Vault drained
    }

    function test_2_SafeAccessControl() public {
        console.log("=== ACCESS CONTROL ATTACK MIGITATION ===");

        console.log("[STEP 0] Initial state");
        uint256 balanceBefore = attacker.balance;
        console.log("  Vault balance:", vault.balance() / 1e18, "ETH");
        console.log("  Attacker balance:", balanceBefore / 1e18, "ETH\n");

        console.log("[STEP 1] Execute access control attack");
        vm.startPrank(attacker);
        // Expect revert due to access control
        vm.expectRevert();
        // Attacker tries to drain the vault
        vault.withdraw();
        vm.stopPrank();
        console.log("  Access control attack refused\n");

        console.log("[STEP 2] Results");
        uint256 balanceAfter = attacker.balance;
        console.log("  Vault balance:", vault.balance() / 1e18, "ETH");
        console.log("  Attacker balance:", balanceAfter / 1e18, "ETH");

        assertEq(balanceAfter, balanceBefore); // No funds gained
        assertEq(address(vault).balance, DEPOSIT_AMOUNT); // Vault intact
    }
}
