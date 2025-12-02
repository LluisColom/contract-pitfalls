// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract VulnerableLottery {
    address[] public players;

    function join() external payable {
        require(msg.value == 1 ether, "Need 1 ETH");
        players.push(msg.sender);
    }

    function random() public view returns (uint256) {
        // VULNERABILITY: Weak randomness — predictable BEFORE execution
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
    }

    function pickWinner() external returns (address winner) {
        require(players.length > 0, "No players");
        uint256 idx = random() % players.length;
        winner = players[idx];

        // send all ETH to winner
        payable(winner).transfer(address(this).balance);

        // reset
        delete players;
    }

    function cancel() external {
        require(players.length > 0, "No players to refund");

        // VULNERABILITY: Unbounded loop - can run out of gas
        for (uint256 i = 0; i < players.length; i++) {
            address player = players[i];

            // VULNERABILITY: Push pattern - one failure blocks all refunds
            (bool success,) = player.call{ value: 1 ether }("");
            require(success, "Refund failed");
        }

        // reset
        delete players;
    }

    // helper for tests
    function getPlayers() external view returns (address[] memory) {
        return players;
    }

    receive() external payable { }
}
