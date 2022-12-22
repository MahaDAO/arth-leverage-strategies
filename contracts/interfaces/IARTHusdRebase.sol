// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Wrapper} from "./IERC20Wrapper.sol";

interface IARTHusdRebase is IERC20Wrapper {
    function gonsPerFragment() external view returns (uint256);

    function gonsDecimals() external view returns (uint256);

    function gonsPercision() external view returns (uint256);
}
