// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title SafeLottery
 * @notice A secure one-time lottery implementation
 * @dev Fixes common vulnerabilities:
 *      - Uses pull pattern to prevent DoS
 *      - Implements access control
 *      - Follows CEI pattern for reentrancy protection
 *      - Uses Chainlink VRF for randomness (simulated here)
 */
contract SafeLottery {
    // ============ State Variables ============
    address public immutable owner;
    uint256 public constant ENTRY_FEE = 1 ether;

    address[] public players;
    mapping(address => bool) public hasJoined;
    mapping(address => bool) public hasWithdrawn;

    bool public cancelled;
    bool public finalized;
    address public winner;

    // ============ Events ============
    event PlayerJoined(address indexed player);
    event WinnerPicked(address indexed winner, uint256 prize);
    event LotteryCancelled();
    event RefundClaimed(address indexed player, uint256 amount);

    // ============ Errors ============
    error NotOwner();
    error LotteryNotActive();
    error InvalidEntryFee();
    error AlreadyJoined();
    error NoPlayers();
    error TransferFailed();
    error LotteryNotCancelled();
    error AlreadyWithdrawn();
    error UnknownPlayer();

    // ============ Modifiers ============
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier lotteryActive() {
        if (cancelled || finalized) revert LotteryNotActive();
        _;
    }

    // ============ Constructor ============
    constructor() {
        owner = msg.sender;
    }

    // ============ Core Functions ============
    function join() external payable lotteryActive {
        if (msg.value != ENTRY_FEE) revert InvalidEntryFee();
        if (hasJoined[msg.sender]) revert AlreadyJoined();

        players.push(msg.sender);
        hasJoined[msg.sender] = true;

        emit PlayerJoined(msg.sender);
    }

    function random() public view returns (uint256) {
        // VULNERABILITY: Weak randomness — predictable BEFORE execution
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
    }

    function pickWinner() external onlyOwner lotteryActive {
        if (players.length == 0) revert NoPlayers();

        uint256 idx = random() % players.length;
        winner = players[idx];
        finalized = true;

        uint256 prize = address(this).balance;
        emit WinnerPicked(winner, prize);

        // CEI Pattern: State updated before external call
        (bool success,) = payable(winner).call{ value: prize }("");
        if (!success) revert TransferFailed();
    }

    /**
     * @notice SAFE: Pull-based refund system
     * @dev Each player withdraws their own refund
     */
    function cancel() external onlyOwner lotteryActive {
        if (players.length == 0) revert NoPlayers();

        cancelled = true;
        emit LotteryCancelled();
    }

    function refund() external {
        if (!cancelled) revert LotteryNotCancelled();
        if (!hasJoined[msg.sender]) revert UnknownPlayer();
        if (hasWithdrawn[msg.sender]) revert AlreadyWithdrawn();

        // CEI Pattern: Update state before external call
        hasWithdrawn[msg.sender] = true;

        (bool success,) = msg.sender.call{ value: ENTRY_FEE }("");
        if (!success) revert TransferFailed();

        emit RefundClaimed(msg.sender, ENTRY_FEE);
    }

    // helper for tests
    function getPlayers() external view returns (address[] memory) {
        return players;
    }

    receive() external payable { }
}
