// SPDX-License-Identifier: GNU-3

pragma solidity ^0.8.0;

interface ILeverageAccount {
  function approveStrategy(address strategy) external;

  function revokeStrategy(address strategy) external;

  function callFn(address target, bytes memory signature) external;

  function canExecute(address who) external returns (bool);
}
