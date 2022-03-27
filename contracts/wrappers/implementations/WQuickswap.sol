// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IMasterChefV2} from "../../interfaces/IMasterChefV2.sol";
import {WStakingRewards} from "../WStakingRewards.sol";

interface IMiniApeV2 is IMasterChefV2 {
  function pendingBanana(uint256 _pid, address _user) external view returns (uint256);
}

contract WQuickswap is WStakingRewards {
  constructor(
    string memory _name,
    string memory _symbol,
    address _staking,
    address _underlying,
    address _rewardToken,
    address _rewardDestination,
    uint256 _rewardFeeRate,
    address _governance
  )
    WStakingRewards(
      _name,
      _symbol,
      _staking,
      _underlying,
      _rewardToken,
      _rewardDestination,
      _rewardFeeRate,
      _governance
    )
  {
    // do nothing
  }

  /// @dev pending rewards
  function accumulatedRewards() external view virtual override returns (uint256) {
    return 0;
  }

  function accumulatedRewardsFor(address _user) external view virtual override returns (uint256) {
    return 0;
  }
}
