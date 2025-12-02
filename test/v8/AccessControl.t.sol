// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v8/VulnerableVault.sol";
import "../../src/v8/SafeVault.sol";

contract AccessControl is Test {
    address victim;
    address attacker;
    uint256 constant DEPOSIT_AMOUNT = 10 ether;

    function setUp() public {
        victim = makeAddr("victim");
        attacker = makeAddr("attacker");
    }

    function test_1_AccessControlAttack() public {
        console.log("=== ACCESS CONTROL ATTACK DEMO ===\n");

        // Deploy VulnerableVault as victim
        vm.startPrank(victim);
        VulnerableVault vault = new VulnerableVault();
        // Victim stores ETH to the vault
        vm.deal(victim, DEPOSIT_AMOUNT);
        vault.deposit{ value: DEPOSIT_AMOUNT }();
        vm.stopPrank();

        uint256 balanceBefore = attacker.balance;
        console.log("Vault balance before attack:", vault.balance() / 1e18, "ETH");
        console.log("Attacker balance before:   ", balanceBefore / 1e18, "ETH");

        console.log("\n[!] Executing access control attack...\n");
        vm.startPrank(attacker);
        // Attacker drains the vault
        vault.withdraw();
        vm.stopPrank();

        uint256 balanceAfter = attacker.balance;
        console.log("Vault balance after attack:", vault.balance() / 1e18, "ETH");
        console.log("Attacker balance before:   ", balanceAfter / 1e18, "ETH");

        assertGt(balanceAfter, balanceBefore);
        assertEq(address(vault).balance, 0); // Vault drained
    }

    function test_2_SafeAccessControl() public {
        console.log("=== ACCESS CONTROL ATTACK PREVENTION ===\n");

        // Deploy SafeVault as victim
        vm.startPrank(victim);
        SafeVault vault = new SafeVault();
        // Victim stores ETH to the vault
        vm.deal(victim, DEPOSIT_AMOUNT);
        vault.deposit{ value: DEPOSIT_AMOUNT }();
        vm.stopPrank();

        uint256 balanceBefore = attacker.balance;
        console.log("Vault balance before attack:", vault.balance() / 1e18, "ETH");
        console.log("Attacker balance before:   ", balanceBefore / 1e18, "ETH");

        console.log("\n[!] Executing access control attack...\n");
        vm.startPrank(attacker);
        // Expect revert due to access control
        vm.expectRevert();
        // Attacker tries to drain the vault
        vault.withdraw();
        vm.stopPrank();

        uint256 balanceAfter = attacker.balance;
        console.log("Vault balance after attack:", vault.balance() / 1e18, "ETH");
        console.log("Attacker balance before:   ", balanceAfter / 1e18, "ETH");

        assertEq(balanceAfter, balanceBefore); // No funds gained
        assertEq(address(vault).balance, DEPOSIT_AMOUNT); // Vault intact
    }
}
