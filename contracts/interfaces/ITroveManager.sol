// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Common interface for the Trove Manager.
interface ITroveManager {
  function setAddresses(
    address _borrowerOperationsAddress,
    address _activePoolAddress,
    address _defaultPoolAddress,
    address _stabilityPoolAddress,
    address _gasPoolAddress,
    address _collSurplusPoolAddress,
    address _lusdTokenAddress,
    address _sortedTrovesAddress,
    address _governanceAddress,
    address _wethAddress
  ) external;

  function stabilityPool() external view returns (address);

  function lusdToken() external view returns (IERC20);

  function getTroveOwnersCount() external view returns (uint256);

  function getTroveFromTroveOwnersArray(uint256 _index) external view returns (address);

  function getNominalICR(address _borrower) external view returns (uint256);

  function getCurrentICR(address _borrower, uint256 _price) external view returns (uint256);

  function liquidate(address _borrower) external;

  function liquidateTroves(uint256 _n) external;

  function batchLiquidateTroves(address[] calldata _troveArray) external;

  function redeemCollateral(
    uint256 _amount,
    address _firstRedemptionHint,
    address _upperPartialRedemptionHint,
    address _lowerPartialRedemptionHint,
    uint256 _partialRedemptionHintNICR,
    uint256 _maxIterations,
    uint256 _maxFee
  ) external;

  function updateStakeAndTotalStakes(address _borrower) external returns (uint256);

  function updateTroveRewardSnapshots(address _borrower) external;

  function addTroveOwnerToArray(address _borrower) external returns (uint256 index);

  function applyPendingRewards(address _borrower) external;

  function getPendingETHReward(address _borrower) external view returns (uint256);

  function getPendingLUSDDebtReward(address _borrower) external view returns (uint256);

  function hasPendingRewards(address _borrower) external view returns (bool);

  function getEntireDebtAndColl(address _borrower)
    external
    view
    returns (
      uint256 debt,
      uint256 coll,
      uint256 pendingLUSDDebtReward,
      uint256 pendingETHReward
    );

  function closeTrove(address _borrower) external;

  function removeStake(address _borrower) external;

  function getRedemptionRate() external view returns (uint256);

  function getRedemptionRateWithDecay() external view returns (uint256);

  function getRedemptionFeeWithDecay(uint256 ethDrawn) external view returns (uint256);

  function getBorrowingRate() external view returns (uint256);

  function getBorrowingRateWithDecay() external view returns (uint256);

  function getBorrowingFee(uint256 _debt) external view returns (uint256);

  function getBorrowingFeeWithDecay(uint256 _debt) external view returns (uint256);

  function decayBaseRateFromBorrowing() external;

  function getTroveStatus(address _borrower) external view returns (uint256);

  function getTroveStake(address _borrower) external view returns (uint256);

  function getTroveDebt(address _borrower) external view returns (uint256);

  function getTroveFrontEnd(address _borrower) external view returns (address);

  function getTroveColl(address _borrower) external view returns (uint256);

  function setTroveStatus(address _borrower, uint256 num) external;

  function setTroveFrontEndTag(address _borrower, address _frontEndTag) external;

  function increaseTroveColl(address _borrower, uint256 _collIncrease) external returns (uint256);

  function decreaseTroveColl(address _borrower, uint256 _collDecrease) external returns (uint256);

  function increaseTroveDebt(address _borrower, uint256 _debtIncrease) external returns (uint256);

  function decreaseTroveDebt(address _borrower, uint256 _collDecrease) external returns (uint256);

  function getTCR(uint256 _price) external view returns (uint256);

  function checkRecoveryMode(uint256 _price) external view returns (bool);
}
