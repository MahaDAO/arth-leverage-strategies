// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEllipsisSwap {
  function get_virtual_price() external view returns (uint256);

  function remove_liquidity(
    address pool,
    uint256 burn_amount,
    uint256[] memory min_amounts
  ) external;

  function add_liquidity(
    address pool,
    uint256[] memory _deposit_amounts,
    uint256 min_mint_amount
  ) external;
}
