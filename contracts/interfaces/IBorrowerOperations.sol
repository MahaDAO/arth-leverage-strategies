// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Common interface for the Trove Manager.
interface IBorrowerOperations {
  // --- Events ---
  function setAddresses(
    address _troveManagerAddress,
    address _activePoolAddress,
    address _defaultPoolAddress,
    address _stabilityPoolAddress,
    address _gasPoolAddress,
    address _collSurplusPoolAddress,
    address _sortedTrovesAddress,
    address _lusdTokenAddress,
    address _wethAddress,
    address _governanceAddress
  ) external;

  function registerFrontEnd() external;

  function openTrove(
    uint256 _maxFee,
    uint256 _arthAmount,
    uint256 _ethAmount,
    address _upperHint,
    address _lowerHint,
    address _frontEndTag
  ) external;

  function addColl(
    uint256 _ethAmount,
    address _upperHint,
    address _lowerHint
  ) external;

  function moveETHGainToTrove(
    uint256 _ethAmount,
    address _user,
    address _upperHint,
    address _lowerHint
  ) external;

  function withdrawColl(
    uint256 _amount,
    address _upperHint,
    address _lowerHint
  ) external;

  function withdrawLUSD(
    uint256 _maxFee,
    uint256 _amount,
    address _upperHint,
    address _lowerHint
  ) external;

  function repayLUSD(
    uint256 _amount,
    address _upperHint,
    address _lowerHint
  ) external;

  function closeTrove() external;

  function adjustTrove(
    uint256 _maxFee,
    uint256 _collWithdrawal,
    uint256 _debtChange,
    uint256 _ethAmount,
    bool isDebtIncrease,
    address _upperHint,
    address _lowerHint
  ) external;

  function claimCollateral() external;

  function getCompositeDebt(uint256 _debt) external view returns (uint256);
}
