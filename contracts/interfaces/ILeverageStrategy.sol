// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILeverageStrategy {
    function openPosition(
        uint256 borrowAmount,
        uint256 minExposure,
        bytes calldata data
    ) external;

    function closePosition(uint256 borrowAmount) external;
}
