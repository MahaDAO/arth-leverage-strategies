// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IStakingRewards} from "../interfaces/IStakingRewards.sol";
import {FeeBase} from "./FeeBase.sol";

abstract contract WStakingRewards is FeeBase, ERC20, ReentrancyGuard, IERC20Wrapper {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  IStakingRewards public staking; // Staking reward contract address
  IERC20 public underlying; // Underlying token address
  IERC20 public rewardToken; // Reward token address

  uint256 private constant MAX_UINT256 = type(uint128).max;

  mapping (address => address) public referralMapping;

  constructor(
    string memory _name,
    string memory _symbol,
    address _staking,
    address _underlying,
    address _rewardToken,
    address _rewardDestination,
    uint256 _rewardFeeRate,
    address _governance
  ) ERC20(_name, _symbol) {
    staking = IStakingRewards(_staking);
    underlying = IERC20(_underlying);
    rewardToken = IERC20(_rewardToken);
    underlying.safeApprove(_staking, MAX_UINT256);

    _setRewardFeeAddress(_rewardDestination);
    _setRewardFeeRate(_rewardFeeRate);
    _transferOwnership(_governance);
  }

  function _depositFor(address account, uint256 amount) internal returns (bool) {
    underlying.safeTransferFrom(account, address(this), amount);
    staking.stake(amount);
    _mint(account, amount);
    return true;
  }

  function deposit(uint256 amount) external override nonReentrant returns (bool) {
    return _depositFor(msg.sender, amount);
  }

  function depositWithReference(uint256 amount, address referrer) external nonReentrant returns (bool) {
    require(
      referralMapping[msg.sender] == address(0) || referralMapping[msg.sender] == referrer, 
      "Referrer already present"
    );
    if (referralMapping[msg.sender] == address(0))  referralMapping[msg.sender] = referrer;
    return _depositFor(msg.sender, amount);
  }

  function withdraw(uint256 amount) external override nonReentrant returns (bool) {
    _burn(msg.sender, amount);
    staking.withdraw(amount);
    staking.getReward();
    underlying.safeTransfer(msg.sender, amount);

    // tax and send the earnings
    uint256 earnings = rewardToken.balanceOf(address(this));
    address referrer = referralMapping[msg.sender];

    if (earnings > 0) {
      uint256 referrerEarning = 0;
      if (referrer != address(0)) {
        referrerEarning = earnings.mul(10).div(100);
        rewardToken.safeTransfer(referrer, referrerEarning);
      }

      _chargeFeeAndTransfer(rewardToken, earnings.sub(referrerEarning), msg.sender);
    }
    return true;
  }
}
