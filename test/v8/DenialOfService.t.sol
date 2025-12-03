// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v8/Lottery.sol";
import "../../src/attackers/MaliciousPlayer.sol";

contract DenialOfService is Test {
    uint256 constant PARTICIPANTS = 10;
    Lottery lottery;

    function joinMaliciousPlayer() internal {
        MaliciousPlayer attacker = new MaliciousPlayer();
        vm.deal(address(attacker), 2 ether);
        vm.prank(address(attacker));
        lottery.join{ value: 1 ether }();
        console.log("  Malicious player joined the lottery");
    }

    function setUp() public {
        console.log("=== SETUP ===");
        lottery = new Lottery();
        console.log("  Lottery deployed\n");

        // Add initial participants
        for (uint256 i = 0; i < PARTICIPANTS; i++) {
            address player = address(uint160(i + 1000));
            vm.deal(player, 2 ether);
            vm.prank(player);
            lottery.join{ value: 1 ether }();
        }
    }

    function test_1_UnboundedLoopDoS() public {
        console.log("=== UNBOUNDED LOOP DoS ATTACK ===");

        console.log("  Total players:", lottery.getPlayers().length);
        console.log("  Cancelling lottery...");
        uint256 gasBefore = gasleft();
        lottery.unsafe_cancel();
        uint256 gasUsed = gasBefore - gasleft();
        console.log("  Gas used:", gasUsed);

        uint256 gasPerPlayer = gasUsed / PARTICIPANTS;
        console.log("  Gas used per player:", gasPerPlayer, "gas");
        console.log("  Max players before DoS (block gas limit ~30M):", 30_000_000 / gasPerPlayer);
        console.log("  Max players + 1 => Transaction reverts and Lottery ETH is permanently lost");
    }

    function test_2_RevertBasedDoS() public {
        console.log("=== REVERT-BASED DoS ATTACK ===");

        // Attack: Add a player that will revert on refund
        joinMaliciousPlayer();

        console.log("  Total players:", lottery.getPlayers().length);
        console.log("  Cancelling lottery...");

        vm.expectRevert("TransferFailed()");
        lottery.unsafe_cancel();

        console.log("  Cancellation reverted due to malicious player");
        console.log("  Lottery ETH is permanently lost as no one can be refunded");
    }

    function test_3_SafeDoS() public {
        console.log("=== SAFE LOTTERY DoS PREVENTION ===");

        // Attack: Add a malicious player
        joinMaliciousPlayer();

        console.log("  Total players:", lottery.getPlayers().length);
        console.log("  Cancelling lottery...");
        uint256 gasBefore = gasleft();
        lottery.cancel();
        uint256 gasUsed = gasBefore - gasleft();
        console.log("  Gas used:", gasUsed);
        console.log("  Constant gas regardless of player count!");

        vm.prank(address(1001)); // normal player
        lottery.refund();
        require(address(1001).balance == 2 ether, "Normal player refund failed");
        console.log("  Normal player refunded successfully despite malicious player");
    }
}
