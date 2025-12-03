// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/v8/Trader.sol";
import "../../src/attackers/SandwichBot.sol";

contract FrontRunning is Test {
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    uint256 constant VICTIM_AMOUNT = 50_000 ether; // Victim wants to swap 50K DAI
    uint256 constant BOT_AMOUNT = 100_000 ether; // Bot uses 100K DAI to sandwich

    Trader public victim;
    SandwichBot public bot;

    function setUp() public {
        // Fork mainnet at a specific block for reproducibility
        console.log("\n=== SETUP (Mainnet Fork) ===");
        vm.createSelectFork(vm.envString("INFURA_URL"), 23_000_000);

        // Deploy victim and bot contracts
        victim = new Trader(UNISWAP_ROUTER, WETH);
        deal(DAI, address(victim), 100_000 ether);
        console.log("Trader deployed");
        console.log("Fund with:", IERC20(DAI).balanceOf(address(victim)) / 1e18, "DAI");

        bot = new SandwichBot(UNISWAP_ROUTER);
        deal(DAI, address(bot), 200_000 ether);
        console.log("SandwichBot deployed");
        console.log("Fund with:", IERC20(DAI).balanceOf(address(bot)) / 1e18, "DAI");
    }

    function expectedSwapOutput(uint256 amount, uint256 slippage) internal view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = WETH;
        uint256[] memory expectedAmounts =
            IUniswapV2Router02(UNISWAP_ROUTER).getAmountsOut(amount, path);

        return (expectedAmounts[1] * (10_000 - slippage)) / 10_000;
    }

    function test_1_SandwichAttack() public {
        console.log("\n=== SANDWICH ATTACK DEMO ===\n");

        // Calculate expected swap output BEFORE any manipulation
        uint256 slippage = 0; // No slippage protection
        uint256 expectedWETH = expectedSwapOutput(VICTIM_AMOUNT, slippage);

        uint256 initialBalance = IERC20(DAI).balanceOf(address(bot));
        console.log("[STEP 0] Initial state");
        console.log("  Bot initial balance:", initialBalance / 1e18, "tokens\n");

        // Bot front-runs
        // In a real scenario, the bot would monitor the mempool and detect the victim's tx
        console.log("[STEP 1] Bot front-runs: Buy WETH to push price up\n");
        uint256 wethBought = bot.frontRun(DAI, WETH, BOT_AMOUNT);

        // Victim's swap
        // In a real scenario, the tx would be waiting in the mempool
        console.log("[STEP 2] Victim's swap executes at inflated price\n");
        victim.swapTokens(DAI, WETH, VICTIM_AMOUNT, 0); // NO SLIPPAGE PROTECTION!

        // Bot back-runs
        console.log("[STEP 3] Bot back-runs: Sell WETH for profit\n");
        bot.backRun(WETH, DAI, wethBought);

        // Calculate profit and loss
        uint256 finalBalance = IERC20(DAI).balanceOf(address(bot));
        uint256 profit = finalBalance - initialBalance;

        uint256 actualWETH = IERC20(WETH).balanceOf(address(victim));
        uint256 victimLoss = expectedWETH - actualWETH;

        // Assertions
        assertGt(profit, 0, "Sandwich attack should be profitable");
        assertGt(victimLoss, 0, "Victim must lose money");

        console.log("[STEP 4] Results\n");
        console.log("  Victim loss %:", (victimLoss * 10_000) / expectedWETH, "bps");
        console.log("  Bot profit:", profit / 1e18, "DAI");
        console.log("  Bot profit %:", (profit * 10_000) / BOT_AMOUNT, "bps");
    }

    function test_2_SafeMev() public {
        console.log("\n=== SLIPPAGE PROTECTION DEMO ===\n");

        // Victim calculates expected output BEFORE any manipulation (with slippage tolerance)
        uint256 slippage = 50; // 0.5% slippage toleranceq
        uint256 minAmountOut = expectedSwapOutput(VICTIM_AMOUNT, slippage);

        uint256 initialBalance = IERC20(DAI).balanceOf(address(bot));
        console.log("[STEP 0] Initial state");
        console.log("  Bot initial balance:", initialBalance / 1e18, "tokens");
        console.log("  Minimum expected swap output is:", minAmountOut / 1e18, "WETH\n");

        // Bot front-runs
        // In a real scenario, the bot would monitor the mempool and detect the victim's tx
        console.log("[STEP 1] Bot front-runs: Buy WETH to push price up\n");
        uint256 wethBought = bot.frontRun(DAI, WETH, BOT_AMOUNT);

        // Victim's swap
        // In a real scenario, the tx would be waiting in the mempool
        console.log("[STEP 2] Victim's swap executes with slippage tolerance");
        vm.expectRevert(); // We expect this to revert
        victim.swapTokens(DAI, WETH, VICTIM_AMOUNT, minAmountOut); // SLIPPAGE PROTECTION!
        console.log("  Victim's transaction reverts due to the inflated price\n");

        // Bot back-runs
        console.log("[STEP 3] Bot back-runs: Sell WETH for profit\n");
        bot.backRun(WETH, DAI, wethBought);

        // Calculate loss
        uint256 finalBalance = IERC20(DAI).balanceOf(address(bot));
        uint256 loss = initialBalance - finalBalance;

        // Assertions
        assertGt(loss, 0, "Attack should not be profitable");

        console.log("[STEP 4] Results\n");
        console.log("  Victim loss %: 0 bps");
        console.log("  Bot loss:", loss / 1e18, "DAI");
        console.log("  Bot loss %:", (loss * 10_000) / BOT_AMOUNT, "bps");
    }
}
