// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IERC20Wrapper is IERC20 {
  /// @dev Mint ERC20 token
  /// @param amount Token amount to wrap
  function deposit(uint amount) external returns (bool);

  /// @dev Burn ERC20 token to redeem LP ERC20 token back plus SUSHI rewards.
  /// @param amount Token amount to burn
  function withdraw(uint amount) external returns (bool);
}
