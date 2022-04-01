// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurveSwapRouter {
  function sellARTHUSDForExact(
    uint256 amountARTHUSDInForBUSD,
    uint256 amountARTHUSDInForUSDC,
    uint256 amountARTHUSDInForUSDT,
    uint256 amountBUSDOutMin,
    uint256 amountUSDCOutMin,
    uint256 amountUSDTOutMin,
    address to,
    uint256 deadline
  ) external;

  function buyARTHUSDForExact(
    uint256 amountBUSDIn,
    uint256 amountUSDCIn,
    uint256 amountUSDTIn,
    uint256 amountARTHUSDOutMinForBUSD,
    uint256 amountARTHUSDOutMinForUSDC,
    uint256 amountARTHUSDOutMinForUSDT,
    address to,
    uint256 deadline
  ) external;
  
  function sellARTHForExact(
    uint256 amountARTHInForBUSD,
    uint256 amountARTHInForUSDC,
    uint256 amountARTHInForUSDT,
    uint256 amountBUSDOutMin,
    uint256 amountUSDCOutMin,
    uint256 amountUSDTOutMin,
    address to,
    uint256 deadline
  ) external;

  function buyARTHForExact(
    uint256 amountBUSDIn,
    uint256 amountUSDCIn,
    uint256 amountUSDTIn,
    uint256 amountARTHMinForBUSD,
    uint256 amountARTHMinForUSDC,
    uint256 amountARTHMinForUSDT,
    address to,
    uint256 deadline
  ) external;
}
