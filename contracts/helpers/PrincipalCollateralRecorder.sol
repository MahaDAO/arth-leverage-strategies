// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IPrincipalCollateralRecorder} from "../interfaces/IPrincipalCollateralRecorder.sol";

contract PrincipalCollateralRecorder is IPrincipalCollateralRecorder {
  // Leverage acc => strategy name => amounts.
  mapping(address => mapping(string => PrinciaplCollateralData)) public principalAmounts;

  event PrincipalCollateralRecorded(
    address account,
    string strategy,
    PrinciaplCollateralData data,
    uint256 timestamp
  );

  function recordPrincipalCollateral(
    string memory name,
    uint256 amount0,
    uint256 amount1,
    uint256 amount2
  ) external override {
    PrinciaplCollateralData memory data = PrinciaplCollateralData({
      name: name,
      amount0: amount0,
      amount1: amount1,
      amount2: amount2
    });

    principalAmounts[msg.sender][name] = data;
    emit PrincipalCollateralRecorded(msg.sender, name, data, block.timestamp);
  }
}
