// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IARTHETHRouter {
    function swapETHtoARTH(address to, uint256 amountOut) external payable returns (uint256 ethUsed);

    function swapARTHtoETH(
        address to,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external payable returns (uint256 arthUsed);
}
