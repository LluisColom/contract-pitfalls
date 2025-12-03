// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";

contract Trader {
    IUniswapV2Router02 public immutable router;
    address public immutable WETH;

    constructor(address _router, address _weth) {
        router = IUniswapV2Router02(_router);
        WETH = _weth;
    }

    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut // Unsafe if set to 0 or too low
    )
        external
        returns (uint256)
    {
        // Approve router
        IERC20(tokenIn).approve(address(router), amountIn);

        // Build path
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // Execute swap with slippage protection (reverts if output < minAmountOut)
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            minAmountOut, // Protection: rejects sandwich attacks
            path,
            address(this),
            block.timestamp + 300
        );

        console.log("  ************* VICTIM SWAP *************");
        console.log("  Input: ", amountIn / 1e18, "DAI");
        console.log("  Min expected:", minAmountOut / 1e18, "WETH");
        console.log("  Received:", amounts[1] / 1e18, "WETH");
        console.log("  *************************************\n");
        return amounts[1];
    }
}
