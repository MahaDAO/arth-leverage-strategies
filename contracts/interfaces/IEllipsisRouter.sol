// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEllipsisRouter {
  function sellARTHForExact(
    uint256 amountArthInMax,
    uint256 amountBUSDOut,
    uint256 amountUSDCOut,
    uint256 amountUSDTOut,
    address to,
    uint256 deadline
  ) external;

  function buyARTHForExact(
    uint256 amountBUSDIn,
    uint256 amountUSDCIn,
    uint256 amountUSDTIn,
    uint256 amountARTHOutMin,
    address to,
    uint256 deadline
  ) external;

  function estimateARTHtoSell(
    uint256 busdNeeded,
    uint256 usdcNeeded,
    uint256 usdtNeeded
  ) external view returns (uint256);

  function estimateARTHtoBuy(
    uint256 busdToSell,
    uint256 usdtToSell,
    uint256 usdcToSell
  ) external view returns (uint256);
}
