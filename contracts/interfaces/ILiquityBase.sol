// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./IPriceFeed.sol";

interface ILiquityBase {
    function MIN_NET_DEBT() external view returns (uint256);
    function getPriceFeed() external view returns (IPriceFeed);
}
