// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../../src/v8/OracleAttacker.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IERC20.sol";

contract VulnerableLending {
    IUniswapV2Pair public immutable uniswapPair; // WETH/DAI pair
    address public immutable WETH;
    address public immutable DAI;

    mapping(address => uint256) public collateral; // ETH deposited
    mapping(address => uint256) public borrowed; // DAI borrowed

    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateralization

    // Events
    event CollateralDeposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);

    constructor(address _uniswapPair, address _weth, address _dai) {
        uniswapPair = IUniswapV2Pair(_uniswapPair);
        WETH = _weth;
        DAI = _dai;

        require(
            uniswapPair.token0() == _weth || uniswapPair.token1() == _weth, "Pair must contain WETH"
        );
        require(
            uniswapPair.token0() == _dai || uniswapPair.token1() == _dai, "Pair must contain DAI"
        );
    }

    // VULNERABILITY: Uses spot price from Uniswap
    // Can be manipulated with flash loans!
    function getETHPrice() public view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = uniswapPair.getReserves();

        // Verify token order
        require(uniswapPair.token0() == DAI, "DAI must be token0");
        require(uniswapPair.token1() == WETH, "WETH must be token1");

        // Price formula: price = reserve_DAI / reserve_WETH DAI/ETH
        uint256 price = (uint256(reserve0) * 1e18) / uint256(reserve1);
        return price;
    }

    function depositCollateral() external payable {
        require(msg.value > 0, "Must deposit ETH");

        collateral[msg.sender] += msg.value;

        console.log("Deposited", msg.value / 1e18, "ETH as collateral");

        emit CollateralDeposited(msg.sender, msg.value);
    }

    function borrow(uint256 daiAmount) external {
        console.log("\n=== BORROW REQUEST ===");
        console.log("User:", msg.sender);
        console.log("Wants to borrow:", daiAmount / 1e18, "DAI");
        console.log("User's collateral:", collateral[msg.sender] / 1e18, "ETH");

        // Get current ETH price (VULNERABLE!)
        uint256 ethPrice = getETHPrice();

        // Calculate collateral value in DAI
        uint256 collateralValue = (collateral[msg.sender] * ethPrice) / 1e18;
        console.log("Collateral value:", collateralValue / 1e18, "DAI");

        // Calculate max borrow (account for existing borrows)
        uint256 maxBorrow = (collateralValue * 100) / COLLATERAL_RATIO;
        console.log("Max can borrow:", maxBorrow / 1e18, "DAI");
        console.log("Already borrowed:", borrowed[msg.sender] / 1e18, "DAI");

        uint256 availableToBorrow = maxBorrow - borrowed[msg.sender];
        console.log("Available to borrow:", availableToBorrow / 1e18, "DAI");

        require(daiAmount <= availableToBorrow, "Insufficient collateral");

        // Update borrowed amount
        borrowed[msg.sender] += daiAmount;

        // Transfer DAI to borrower
        require(IERC20(DAI).transfer(msg.sender, daiAmount), "DAI transfer failed");

        console.log("Borrowed", daiAmount / 1e18, "DAI");

        emit Borrowed(msg.sender, daiAmount);
    }

    function repay(uint256 daiAmount) external {
        require(borrowed[msg.sender] >= daiAmount, "Repaying too much");

        // Transfer DAI from borrower
        require(
            IERC20(DAI).transferFrom(msg.sender, address(this), daiAmount), "DAI transfer failed"
        );

        borrowed[msg.sender] -= daiAmount;

        emit Repaid(msg.sender, daiAmount);
    }

    function withdrawCollateral(uint256 amount) external {
        require(collateral[msg.sender] >= amount, "Insufficient collateral");

        // Check if withdrawal would make account undercollateralized
        uint256 remainingCollateral = collateral[msg.sender] - amount;
        uint256 ethPrice = getETHPrice();
        uint256 collateralValue = (remainingCollateral * ethPrice) / 1e18;
        uint256 requiredCollateral = (borrowed[msg.sender] * COLLATERAL_RATIO) / 100;

        require(collateralValue >= requiredCollateral, "Would be undercollateralized");

        collateral[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    // Helper: Fund the contract with DAI for lending
    receive() external payable { }
}

