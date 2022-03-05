// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Wrapper {
  /// @dev Mint ERC20 token
  /// @param amount Token amount to wrap
  function deposit(uint amount) external;

  /// @dev Burn ERC20 token to redeem LP ERC20 token back plus SUSHI rewards.
  /// @param amount Token amount to burn
  function withdraw(uint amount) external;
}
