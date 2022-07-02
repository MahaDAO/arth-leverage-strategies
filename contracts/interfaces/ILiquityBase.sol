// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./IPriceFeed.sol";

interface ILiquityBase {
    function getPriceFeed() external view returns (IPriceFeed);
}
