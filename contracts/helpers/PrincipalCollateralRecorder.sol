// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IPrincipalCollateralRecorder } from "../interfaces/IPrincipalCollateralRecorder.sol";

contract PrincipalCollateralRecorder is IPrincipalCollateralRecorder {
  // Leverage acc => strategy name => amounts.
  mapping (address => mapping(string => PrinciaplCollateralData)) public principalAmounts;

  event PrincipalCollateralRecorded(
    address account,
    string strategy,
    PrinciaplCollateralData data,
    uint256 timestamp
  );

  function recordPrincipalCollateral(
    string memory name, 
    address token0,
    address token1,
    address token2,
    uint256 amount0,
    uint256 amount1,
    uint256 amount2
  ) external override {
    PrinciaplCollateralData memory data = PrinciaplCollateralData({
      name: name,
      token0: token0,
      token1: token1,
      token2: token2,
      amount0: amount0,
      amount1: amount1,
      amount2: amount2
    });

    principalAmounts[msg.sender][name] = data;
    emit PrincipalCollateralRecorded(msg.sender, name, data, block.timestamp);
  }
}
