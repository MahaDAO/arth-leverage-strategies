// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAaveLendingPool {
  function deposit(
    address token,
    uint256 amount,
    address receiver,
    uint16 referral
  ) external;

  function withdraw(
    address token,
    uint256 amount,
    address receiver
  ) external;
}
