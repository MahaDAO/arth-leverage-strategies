// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILeverageStrategy {
  function openPosition(
    uint256[] memory borrowedCollateral,
    uint256[] memory principalCollateral,
    uint256 minExpectedCollateralRatio,
    uint256 maxBorrowingFee
  ) external;

  function closePosition(uint256[] memory minExpectedCollateral) external;

  function rewardsEarned(address who) external view returns (uint256);

  event PositionOpened(
    address indexed who,
    address collateral,
    uint256[] finalExposure,
    uint256[] principalCollateral
  );

  event PositionClosed(
    address indexed who,
    address collateral,
    uint256 collateralRedeemed,
    uint256 debt
  );
}
