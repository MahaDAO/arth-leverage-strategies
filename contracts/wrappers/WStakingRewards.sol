// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { IERC20Wrapper } from "../interfaces/IERC20Wrapper.sol";
import { IStakingRewards } from "../interfaces/IStakingRewards.sol";
import { FeeBase } from "./FeeBase.sol";

contract WStakingRewards is FeeBase, ERC20, ReentrancyGuard, IERC20Wrapper {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  IStakingRewards public staking; // Staking reward contract address
  IERC20 public underlying; // Underlying token address
  IERC20 public rewardToken; // Reward token address

  uint256 private constant MAX_UINT256 = type(uint128).max;

  constructor(
    string memory _name,
    string memory _symbol,
    address _staking,
    address _underlying,
    address _reward,
    address _rewardDestination,
    address _governance
  ) ERC20(_name, _symbol) {
    staking = IStakingRewards(_staking);
    underlying = IERC20(_underlying);
    rewardToken = IERC20(_reward);
    underlying.safeApprove(_staking, MAX_UINT256);

    _setRewardFeeAddress(_rewardDestination);
    _transferOwnership(_governance);
  }

  function deposit(uint amount) external override nonReentrant returns (bool) {
    underlying.safeTransferFrom(msg.sender, address(this), amount);
    staking.stake(amount);
    _mint(msg.sender, amount);
    return true;
  }

  function withdraw(uint amount) external override nonReentrant returns (bool) {
    _burn(msg.sender, amount);
    staking.withdraw(amount);
    staking.getReward();
    underlying.safeTransfer(msg.sender, amount);

    // tax and send the earnings
    uint256 earnings = rewardToken.balanceOf(address(this));
    if (earnings > 0) _chargeFeeAndTransfer(rewardToken, earnings, msg.sender);
    return true;
  }
}
