// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { IERC20Wrapper } from "../interfaces/IERC20Wrapper.sol";
import { IMasterChef } from "../interfaces/IMasterChef.sol";
import { FeeBase } from "./FeeBase.sol";


contract WMasterChef is FeeBase, ERC20, ReentrancyGuard, IERC20Wrapper {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  uint public pid;
  IMasterChef public chef; // Sushiswap masterChef
  IERC20 public rewardToken; // reward token
  IERC20 public lpToken; // Sushi token

  uint256 private constant MAX_UINT256 = type(uint128).max;

  constructor(
    string memory _name, string memory _symbol,
    IMasterChef _chef, uint _pid
  ) ERC20(_name, _symbol) {
    chef = _chef;

    (address _lpToken, , , ) = chef.poolInfo(pid);

    lpToken = IERC20(_lpToken);
    rewardToken = IERC20(_chef.sushi());
    pid = _pid;
  }

  /// @dev Mint ERC20 token
  /// @param amount Token amount to wrap
  function deposit(uint256 amount) external nonReentrant override {
    // take the LP tokens
    lpToken.safeTransferFrom(msg.sender, address(this), amount);

    // stake into the masterchef contract
    lpToken.safeIncreaseAllowance(address(chef), amount);
    chef.deposit(pid, amount);

    _mint(msg.sender, amount);
  }

  /// @dev Burn ERC20 token to redeem LP ERC20 token back plus SUSHI rewards.
  /// @param amount Token amount to burn
  function withdraw(uint256 amount) external nonReentrant override {
    _burn(msg.sender, amount);

    // withdraw and send the lp token back
    chef.withdraw(pid, amount);
    lpToken.safeTransfer(msg.sender, amount);

    // tax and send the earnings
    uint256 earnings = rewardToken.balanceOf(address(this));
    if (earnings > 0) _chargeFeeAndTransfer(rewardToken, earnings, msg.sender);
  }
}
