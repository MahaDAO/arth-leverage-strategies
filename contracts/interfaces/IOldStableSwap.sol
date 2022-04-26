// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IStableSwap } from "./IStableSwap.sol";

interface IOldStableSwap is IStableSwap {
    function exchange(
    int128 i,
    int128 j,
    uint256 dx,
    uint256 min_dy
  ) external returns (uint256);
}
