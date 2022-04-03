// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, IERC20WithDecimals} from "../interfaces/IERC20WithDecimals.sol";
import {IZapDepositor} from "../interfaces/IZapDepositor.sol";
import {IStableSwap} from "../interfaces/IStableSwap.sol";
import {ICurveSwapRouter} from "../interfaces/ICurveSwapRouter.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { IARTHusdRebase } from "../interfaces/IARTHusdRebase.sol";

contract CurveARTHRouter is ICurveSwapRouter {
  using SafeMath for uint256;

  IERC20WithDecimals public lp;
  IZapDepositor public zap;
  address public pool;

  IARTHusdRebase public arthUsd;
  IERC20WithDecimals public arth;
  IERC20WithDecimals public usdc;
  IERC20WithDecimals public usdt;
  IERC20WithDecimals public busd;

  address private me;

  constructor(
    address _zap,
    address _lp,
    address _pool,
    address _arth,
    address _arthUsd,
    address _usdc,
    address _usdt,
    address _busd
  ) {
    pool = _pool;

    arthUsd = IARTHusdRebase(_arthUsd);
    zap = IZapDepositor(_zap);

    lp = IERC20WithDecimals(_lp);
    arth = IERC20WithDecimals(_arth);
    usdc = IERC20WithDecimals(_usdc);
    usdt = IERC20WithDecimals(_usdt);
    busd = IERC20WithDecimals(_busd);

    me = address(this);
  }

  function _sellARTHUSDForExact(
    uint256 amountARTHUSDInForBUSD,
    uint256 amountARTHUSDInForUSDC,
    uint256 amountARTHUSDInForUSDT,
    uint256 amountBUSDOutMin,
    uint256 amountUSDCOutMin,
    uint256 amountUSDTOutMin,
    address to,
    uint256 deadline
  ) internal {
    IStableSwap swap = IStableSwap(pool);

    if (amountBUSDOutMin > 0) {
      uint256 amountBUSDOutExpected = swap.get_dy_underlying(0, 1, amountARTHUSDInForBUSD);
      _requireExpectedOutGreaterThanMinOut(amountBUSDOutExpected, amountBUSDOutMin);
      swap.exchange_underlying(0, 1, amountARTHUSDInForBUSD, amountBUSDOutExpected, me);
    }

    if (amountUSDCOutMin > 0) {
      uint256 amountUSDCOutExpected = swap.get_dy_underlying(0, 2, amountARTHUSDInForUSDC);
      _requireExpectedOutGreaterThanMinOut(amountUSDCOutExpected, amountUSDCOutMin);
      swap.exchange_underlying(0, 2, amountARTHUSDInForUSDC, amountUSDCOutExpected, me);
    }

    if (amountUSDTOutMin > 0) {
      uint256 amountUSDTOutExpected = swap.get_dy_underlying(0, 3, amountARTHUSDInForUSDT);
      _requireExpectedOutGreaterThanMinOut(amountUSDTOutExpected, amountUSDTOutMin);
      swap.exchange_underlying(0, 3, amountARTHUSDInForUSDT, amountUSDTOutExpected, me);
    }

    require(block.timestamp <= deadline, "Swap: Deadline expired");
    _flush(to);
  }

  function sellARTHUSDForExact(
    uint256 amountARTHUSDInForBUSD,
    uint256 amountARTHUSDInForUSDC,
    uint256 amountARTHUSDInForUSDT,
    uint256 amountBUSDOutMin,
    uint256 amountUSDCOutMin,
    uint256 amountUSDTOutMin,
    address to,
    uint256 deadline
  ) external override {
    uint256 amountARTHUSDIn = amountARTHUSDInForBUSD
      .add(amountARTHUSDInForUSDC)
      .add(amountARTHUSDInForUSDT);
    arthUsd.transferFrom(msg.sender, me, amountARTHUSDIn);
    arthUsd.approve(pool, amountARTHUSDIn);

    _sellARTHUSDForExact(
      amountARTHUSDInForBUSD, 
      amountARTHUSDInForUSDC, 
      amountARTHUSDInForUSDT, 
      amountBUSDOutMin, 
      amountUSDCOutMin, 
      amountUSDTOutMin, 
      to, 
      deadline
    );
  }

  function _buyARTHUSDForExact(
    uint256 amountBUSDIn,
    uint256 amountUSDCIn,
    uint256 amountUSDTIn,
    uint256 amountARTHUSDOutMinForBUSD,
    uint256 amountARTHUSDOutMinForUSDC,
    uint256 amountARTHUSDOutMinForUSDT,
    uint256 deadline
  ) internal {
    IStableSwap swap = IStableSwap(pool);

    if (amountBUSDIn > 0) {
      busd.transferFrom(msg.sender, me, amountBUSDIn);
      busd.approve(pool, amountBUSDIn);
      uint256 arthUsdAmountExpected = swap.get_dy_underlying(1, 0, amountBUSDIn);
      _requireExpectedOutGreaterThanMinOut(arthUsdAmountExpected, amountARTHUSDOutMinForBUSD);
      swap.exchange_underlying(1, 0, amountBUSDIn, arthUsdAmountExpected, me);
    }

    if (amountUSDCIn > 0) {
      usdc.transferFrom(msg.sender, me, amountUSDCIn);
      usdc.approve(pool, amountUSDCIn);
      uint256 arthUsdAmountExpected = swap.get_dy_underlying(2, 0, amountUSDCIn);
      _requireExpectedOutGreaterThanMinOut(arthUsdAmountExpected, amountARTHUSDOutMinForUSDC);
      swap.exchange_underlying(0, 2, amountUSDCIn, arthUsdAmountExpected, me);
    }

    if (amountUSDTIn > 0) {
      usdt.transferFrom(msg.sender, me, amountUSDTIn);
      usdt.approve(pool, amountUSDTIn);
      uint256 arthUsdAmountExpected = swap.get_dy_underlying(3, 0, amountUSDTIn);
      _requireExpectedOutGreaterThanMinOut(arthUsdAmountExpected, amountARTHUSDOutMinForUSDT);
      swap.exchange_underlying(3, 0, amountUSDTIn, arthUsdAmountExpected, me);
    }

    require(block.timestamp <= deadline, "Swap: Deadline expired");
  }

  function buyARTHUSDForExact(
    uint256 amountBUSDIn,
    uint256 amountUSDCIn,
    uint256 amountUSDTIn,
    uint256 amountARTHUSDOutMinForBUSD,
    uint256 amountARTHUSDOutMinForUSDC,
    uint256 amountARTHUSDOutMinForUSDT,
    address to,
    uint256 deadline
  ) external override {
    _buyARTHUSDForExact(
      amountBUSDIn, 
      amountUSDCIn, 
      amountUSDTIn, 
      amountARTHUSDOutMinForBUSD, 
      amountARTHUSDOutMinForUSDC, 
      amountARTHUSDOutMinForUSDT,
      deadline
    );
    _flush(to);
  }

  function sellARTHForExact(
    uint256 amountARTHInForBUSD,
    uint256 amountARTHInForUSDC,
    uint256 amountARTHInForUSDT,
    uint256 amountBUSDOutMin,
    uint256 amountUSDCOutMin,
    uint256 amountUSDTOutMin,
    address to,
    uint256 deadline
  ) external override {
    uint256 amountARTHIn = amountARTHInForBUSD
      .add(amountARTHInForUSDC)
      .add(amountARTHInForUSDT);
    arth.transferFrom(msg.sender, me, amountARTHIn);

    uint256 arthUSDBalanceFromARTHForBUSD;
    uint256 arthUSDBalanceFromARTHForUSDC;
    uint256 arthUSDBalanceFromARTHForUSDT;

    if (amountBUSDOutMin > 0) {
      arthUsd.deposit(amountARTHInForBUSD);
      arthUSDBalanceFromARTHForBUSD = arthUsd.balanceOf(me);
    }

    if (amountUSDCOutMin > 0) {
      arthUsd.deposit(amountARTHInForUSDC);
      arthUSDBalanceFromARTHForUSDC = arthUsd.balanceOf(me).sub(arthUSDBalanceFromARTHForBUSD);
    }

    if (amountUSDTOutMin > 0) {
      arthUsd.deposit(amountARTHInForUSDT);
      arthUSDBalanceFromARTHForUSDT = arthUsd.balanceOf(me)
        .sub(arthUSDBalanceFromARTHForBUSD)
        .sub(arthUSDBalanceFromARTHForUSDC);
    }

    arthUsd.approve(pool, arthUsd.balanceOf(me));
    _sellARTHUSDForExact(
      arthUSDBalanceFromARTHForBUSD, 
      arthUSDBalanceFromARTHForUSDC, 
      arthUSDBalanceFromARTHForUSDT, 
      amountBUSDOutMin, 
      amountUSDCOutMin,
      amountUSDTOutMin, 
      to, 
      deadline
    );
  }

  function buyARTHForExact(
    uint256 amountBUSDIn,
    uint256 amountUSDCIn,
    uint256 amountUSDTIn,
    uint256 amountARTHUSDOutMinForBUSD,
    uint256 amountARTHUSDOutMinForUSDC,
    uint256 amountARTHUSDOutMinForUSDT,
    address to,
    uint256 deadline
  ) external override {
    _buyARTHUSDForExact(
      amountBUSDIn, 
      amountUSDCIn, 
      amountUSDTIn, 
      amountARTHUSDOutMinForBUSD, 
      amountARTHUSDOutMinForUSDC, 
      amountARTHUSDOutMinForUSDT,
      deadline
    );

    arthUsd.withdraw(
      arthUsd.balanceOf(me).mul(arthUsd.gonsPercision()).div(arthUsd.gonsPerFragment())
    );
    _flush(to);
  }

  function _addLiquidityUsingARTHusd(
    uint256 amountARTHusdIn,
    uint256 amountBUSDIn,
    uint256 amountUSDCIn,
    uint256 amountUSDTIn,
    uint256 minLpTokensOut,
    address to,
    uint256 deadline
  ) internal {
    busd.transferFrom(msg.sender, me, amountBUSDIn);
    usdc.transferFrom(msg.sender, me, amountUSDCIn);
    usdt.transferFrom(msg.sender, me, amountUSDTIn);

    arthUsd.approve(address(zap), amountARTHusdIn);
    busd.approve(address(zap), amountBUSDIn);
    usdc.approve(address(zap), amountUSDCIn);
    usdt.approve(address(zap), amountUSDTIn);

    uint256[4] memory amounts = [amountARTHusdIn, amountBUSDIn, amountUSDCIn, amountUSDTIn];
    
    uint256 expectedLpTokensOut = zap.calc_token_amount(pool, amounts, true);
    _requireExpectedOutGreaterThanMinOut(expectedLpTokensOut, minLpTokensOut);
    
    zap.add_liquidity(
      pool, 
      amounts,
      expectedLpTokensOut
    );

    require(block.timestamp <= deadline, "Swap: tx expired");
    _flush(to);
  }

  function addLiquidityUsingARTHusd(
    uint256 amountARTHusdIn,
    uint256 amountBUSDIn,
    uint256 amountUSDCIn,
    uint256 amountUSDTIn,
    uint256 minLpTokensOut,
    address to,
    uint256 deadline
  ) external override {
    arthUsd.transferFrom(msg.sender, me, amountARTHusdIn);
    _addLiquidityUsingARTHusd(
      amountARTHusdIn, 
      amountBUSDIn, 
      amountUSDCIn, 
      amountUSDTIn, 
      minLpTokensOut, 
      to, 
      deadline
    );
  }

  function addLiquidityUsingARTH(
    uint256 amountARTHIn,
    uint256 amountBUSDIn,
    uint256 amountUSDCIn,
    uint256 amountUSDTIn,
    uint256 minLpTokensOut,
    address to,
    uint256 deadline
  ) external override {
    arth.transferFrom(msg.sender, me, amountARTHIn);
    arthUsd.deposit(amountARTHIn);
   _addLiquidityUsingARTHusd(
      arthUsd.balanceOf(me), 
      amountBUSDIn, 
      amountUSDCIn, 
      amountUSDTIn, 
      minLpTokensOut, 
      to, 
      deadline
    );
  }

  function _removeLiquidityUsingARTHusd(
    uint256 amountLpIn,
    uint256 minBUSDOut,
    uint256 minUSDCOut,
    uint256 minUSDTOut,
    uint256 minARTHusdOut,
    uint256 deadline
  ) internal {
    lp.transferFrom(msg.sender, me, amountLpIn);
    lp.approve(address(zap), amountLpIn);

    uint256[4] memory minAmountsOut = [minARTHusdOut, minBUSDOut, minUSDCOut, minUSDTOut];
    zap.remove_liquidity(pool, amountLpIn, minAmountsOut);

    require(block.timestamp <= deadline, "Swap: expirde");
  }

  function removeLiquidityUsingARTHusd(
    uint256 amountLpIn,
    uint256 minBUSDOut,
    uint256 minUSDCOut,
    uint256 minUSDTOut,
    uint256 minARTHusdOut,
    address to,
    uint256 deadline
  ) external override {
    _removeLiquidityUsingARTHusd(
      amountLpIn,
      minBUSDOut,
      minUSDCOut,
      minUSDTOut,
      minARTHusdOut,
      deadline
    );

    _flush(to);
  }

  function removeLiquidityUsingARTH(
    uint256 amountLpIn,
    uint256 minBUSDOut,
    uint256 minUSDCOut,
    uint256 minUSDTOut,
    uint256 minARTHusdOut,
    address to,
    uint256 deadline
  ) external override {
    _removeLiquidityUsingARTHusd(
      amountLpIn,
      minBUSDOut,
      minUSDCOut,
      minUSDTOut,
      minARTHusdOut,
      deadline
    );

    arthUsd.withdraw(arthUsd.balanceOf(me));
    _flush(to);
  }

  function _flush(address to) internal {
    if (lp.balanceOf(me) > 0) lp.transfer(to, lp.balanceOf(me));
    if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
    if (arthUsd.balanceOf(me) > 0) arthUsd.transfer(to, arthUsd.balanceOf(me));
    if (usdc.balanceOf(me) > 0) usdc.transfer(to, usdc.balanceOf(me));
    if (usdt.balanceOf(me) > 0) usdt.transfer(to, usdt.balanceOf(me));
    if (busd.balanceOf(me) > 0) busd.transfer(to, busd.balanceOf(me));
  }

  function _requireExpectedOutGreaterThanMinOut(uint256 expectedOut, uint256 minOut) internal pure {
    require(expectedOut >= minOut, "Swap: price has moved");
  }
}
