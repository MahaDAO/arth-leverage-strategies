// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILeverageStrategy {
    function openPosition(uint256 amountIn, uint256 borrowAmount) external returns (bool);

    function closePosition() external;

    function calculateSlippage(uint256 amountIn, uint256 borrowAmount) external;
}
