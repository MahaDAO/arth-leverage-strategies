// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { AdvancedMath, SafeMath } from "../utils/AdvancedMath.sol";
import { IERC20Wrapper } from "../interfaces/IERC20Wrapper.sol";
import { IMasterChef } from "../interfaces/IMasterChef.sol";

contract WMasterChef is ERC20, ReentrancyGuard, IERC20Wrapper {
  using SafeMath for uint;
  using AdvancedMath for uint;
  using SafeERC20 for IERC20;

  uint public pid;
  IMasterChef public immutable chef; // Sushiswap masterChef
  IERC20 public immutable sushi; // Sushi token

  uint256 private constant MAX_UINT256 = type(uint128).max;


  constructor(
    string memory _name, string memory _symbol,
    IMasterChef _chef, uint _pid
  ) ERC20(_name, _symbol) {
    chef = _chef;
    sushi = IERC20(_chef.sushi());
    pid = _pid;
  }

  function getUnderlyingToken() external view returns (address) {
    (address lpToken, , , ) = chef.poolInfo(pid);
    return lpToken;
  }

  function getRewardPerShare() public view returns (uint) {
    (, , , uint sushiPerShare) = chef.poolInfo(pid);
    return sushiPerShare;
  }

  /// @dev Mint ERC20 token
  /// @param amount Token amount to wrap
  function deposit(uint amount) external nonReentrant override {
    (address lpToken, , , ) = chef.poolInfo(pid);
    IERC20(lpToken).safeTransferFrom(msg.sender, address(this), amount);

    // We only need to do this once per pool, as LP token"s allowance won"t decrease if it"s -1.
    if (IERC20(lpToken).allowance(address(this), address(chef)) != MAX_UINT256)
      IERC20(lpToken).safeApprove(address(chef), MAX_UINT256);

    chef.deposit(pid, amount);

    _mint(msg.sender, amount);
  }

  /// @dev Burn ERC20 token to redeem LP ERC20 token back plus SUSHI rewards.
  /// @param amount Token amount to burn
  function withdraw(uint amount) external nonReentrant override {
    if (amount == MAX_UINT256) amount = balanceOf(msg.sender);
    // require(amount > uint(0), "nothing to withdraw");

    uint stSushiPerShare = getRewardPerShare();
    _burn(msg.sender, amount);

    chef.withdraw(pid, amount);
    (address lpToken, , , uint enSushiPerShare) = chef.poolInfo(pid);
    IERC20(lpToken).safeTransfer(msg.sender, amount);

    uint stSushi = stSushiPerShare.mul(amount).divCeil(1e12);
    uint enSushi = enSushiPerShare.mul(amount).div(1e12);
    if (enSushi > stSushi) sushi.safeTransfer(msg.sender, enSushi.sub(stSushi));
  }
}
