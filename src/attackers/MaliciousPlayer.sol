// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MaliciousPlayer
 * @notice Joins lottery but rejects refunds to DoS the cancel() function
 */
contract MaliciousPlayer {
    receive() external payable {
        revert("I refuse to accept refunds");
    }
}
