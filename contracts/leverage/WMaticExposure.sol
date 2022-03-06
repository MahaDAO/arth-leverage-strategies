// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/ILeverageStrategy.sol";

contract WMaticExposure is ILeverageStrategy {
    event OpenPosition(uint256 amount, address who);

    function openPosition(uint256 amountIn, uint256 borrowAmount) external override returns(bool) {
        emit OpenPosition(amountIn + borrowAmount, msg.sender);
        return true;
    }

    function closePosition() external override {
        emit OpenPosition(1, msg.sender);
    }

    function calculateSlippage(uint256 amountIn, uint256 borrowAmount) external override {
        // nothing
        emit OpenPosition(amountIn + borrowAmount, msg.sender);
    }
}
