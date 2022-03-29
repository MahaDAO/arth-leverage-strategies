// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEllipsisRouter {
  function sellARTHForExact(
    uint256 amountArthInMax,
    uint256 amountUSDTOut,
    uint256 amountUSDCOut,
    uint256 amountBUSDOut,
    address to,
    uint256 deadline
  ) external;

  function buyARTHForExact(
    uint256 amountUSDTIn,
    uint256 amountUSDCIn,
    uint256 amountBUSDIn,
    uint256 amountARTHOutMin,
    address to,
    uint256 deadline
  ) external;

  function estimateARTHtoSell(
    uint256 usdcNeeded,
    uint256 usdtNeeded,
    uint256 busdNeeded
  ) external view returns (uint256);

  function estimateARTHtoBuy(
    uint256 usdcToSell,
    uint256 usdtToSell,
    uint256 busdToSell
  ) external view returns (uint256);
}
