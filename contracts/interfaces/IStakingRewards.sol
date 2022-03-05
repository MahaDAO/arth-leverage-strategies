// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStakingRewards {
  function rewardPerToken() external view returns (uint);

  function stake(uint amount) external;

  function withdraw(uint amount) external;

  function getReward() external;
}
