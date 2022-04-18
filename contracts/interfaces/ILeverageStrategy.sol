// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILeverageStrategy {
  function openPosition(
    uint256[2] memory borrowedCollateral,
    uint256[2] memory principalCollateral,
    uint256 minExpectedCollateralRatio,
    uint256 maxBorrowingFee
  ) external;

  function closePosition(uint256[2] memory minExpectedCollateral) external;

  function rewardsEarned(address who) external view returns (uint256);

  function underlyingCollateralFromBalance(uint256 bal) external view returns (uint256[2] memory);

  event PositionOpened(
    address indexed who,
    address collateral,
    uint256[2] finalExposure,
    uint256[2] principalCollateral
  );

  event PositionClosed(
    address indexed who,
    address collateral,
    uint256 collateralRedeemed,
    uint256 debt
  );
}
