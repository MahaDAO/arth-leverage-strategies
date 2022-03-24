// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPrincipalCollateralRecorder {
  struct PrinciaplCollateralData {
    string name;
    address token0;
    address token1;
    address token2;
    uint256 amount0;
    uint256 amount1;
    uint256 amount2;
  }

  function recordPrincipalCollateral(
    string memory name, 
    address token0,
    address token1,
    address token2,
    uint256 amount0,
    uint256 amount1,
    uint256 amount2
  ) external;
}
