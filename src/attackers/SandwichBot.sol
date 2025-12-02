// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";

contract SandwichBot {
    IUniswapV2Router02 public immutable router;
    address public immutable owner;

    constructor(address _router) {
        router = IUniswapV2Router02(_router);
        owner = msg.sender;
    }

    function frontRun(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        external
        returns (uint256)
    {
        uint256 amountOut = _swapTokens(tokenIn, tokenOut, amountIn);
        console.log("  ************** FRONT RUN **************");
        console.log("  Input:", amountIn / 1e18, "DAI");
        console.log("  Output:", amountOut / 1e18, "WETH");
        console.log("  ***************************************\n");

        return amountOut;
    }

    function backRun(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        external
        returns (uint256)
    {
        uint256 amountOut = _swapTokens(tokenIn, tokenOut, amountIn);
        console.log("  ************** BACK RUN ***************");
        console.log("  Input:", amountIn / 1e18, "WETH");
        console.log("  Output:", amountOut / 1e18, "DAI");
        console.log("  ***************************************\n");

        return amountOut;
    }

    function _swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        private
        returns (uint256)
    {
        // Approve router
        IERC20(tokenIn).approve(address(router), amountIn);

        // Build path
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // Execute swap
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0, // MEV bots accept any slippage for front-run and back-run
            path,
            address(this),
            block.timestamp
        );

        return amounts[1];
    }
}
