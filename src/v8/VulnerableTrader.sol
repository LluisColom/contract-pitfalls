// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";

contract VulnerableTrader {
    IUniswapV2Router02 public immutable router;
    address public immutable WETH;

    constructor(address _router, address _weth) {
        router = IUniswapV2Router02(_router);
        WETH = _weth;
    }

    function swapTokensVulnerable(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut // Often set too low or to 0!
    )
        external
        returns (uint256)
    {
        console.log("  ************* VICTIM SWAP *************");
        console.log("  Swapping: ", amountIn / 1e18, "tokens");
        console.log("  Min output:", minAmountOut / 1e18);

        // Approve router
        IERC20(tokenIn).approve(address(router), amountIn);

        // Build path
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // Execute swap - VULNERABLE to front-running!
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn, minAmountOut, path, address(this), block.timestamp + 300
        );

        console.log("  Received:", amounts[1] / 1e18, "tokens");
        console.log("  ***************************************\n");
        return amounts[1];
    }
}
