// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
import {IUniswapV3SwapRouter} from "../../interfaces/IUniswapV3SwapRouter.sol";
import {IARTHETHRouter} from "../../interfaces/IARTHETHRouter.sol";

contract ARTHETHRouter is IARTHETHRouter {
    uint24 public fee;
    IERC20 public arth;
    IERC20 public weth;
    IUniswapV3SwapRouter public uniswapV3SwapRouter;

    address private _arth;
    address private _weth;
    address private me;

    constructor(
        address __arth,
        address __weth,
        uint24 _fee,
        address _uniswapV3SwapRouter
    ) {
        fee = _fee;

        arth = IERC20(__arth);
        weth = IERC20(__weth);
        _arth = __arth;
        _weth = __weth;

        uniswapV3SwapRouter = IUniswapV3SwapRouter(_uniswapV3SwapRouter);
        arth.approve(_uniswapV3SwapRouter, type(uint256).max);
        me = address(this);
    }

    function swapETHtoARTH(address to, uint256 amountOut)
        external
        payable
        override
        returns (uint256 ethUsed)
    {
        IUniswapV3SwapRouter.ExactOutputSingleParams memory _params = IUniswapV3SwapRouter
            .ExactOutputSingleParams({
                tokenIn: _weth,
                tokenOut: _arth,
                fee: fee,
                recipient: to,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: msg.value,
                sqrtPriceLimitX96: 0
            });
        ethUsed = uniswapV3SwapRouter.exactOutputSingle{value: msg.value}(_params);
    }

    function swapARTHtoETH(
        address to,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external payable override returns (uint256 arthUsed) {
        arth.transferFrom(msg.sender, me, amountIn);
        IUniswapV3SwapRouter.ExactInputSingleParams memory params = IUniswapV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: _arth,
                tokenOut: _weth,
                fee: fee,
                recipient: to,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });
        arthUsed = uniswapV3SwapRouter.exactInputSingle(params);
    }
}
