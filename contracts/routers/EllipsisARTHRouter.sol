// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, IERC20WithDecimals} from "../interfaces/IERC20WithDecimals.sol";
import {IZapDepositor} from "../interfaces/IZapDepositor.sol";
import {IStableSwap} from "../interfaces/IStableSwap.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IEllipsisRouter} from "../interfaces/IEllipsisRouter.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract EllipsisARTHRouter is IEllipsisRouter {
  using SafeMath for uint256;

  IERC20WithDecimals public lp;
  IZapDepositor public zap;
  address public pool;

  IERC20Wrapper public arthUsd;
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

    arthUsd = IERC20Wrapper(_arthUsd);
    zap = IZapDepositor(_zap);

    lp = IERC20WithDecimals(_lp);
    arth = IERC20WithDecimals(_arth);
    usdc = IERC20WithDecimals(_usdc);
    usdt = IERC20WithDecimals(_usdt);
    busd = IERC20WithDecimals(_busd);

    me = address(this);
  }

  function sellARTHForExact(
    uint256 amountArthInMax,
    uint256 amountBUSDOut,
    uint256 amountUSDCOut,
    uint256 amountUSDTOut,
    address to,
    uint256 deadline
  ) external override {
    IStableSwap swap = IStableSwap(pool);

    uint256 totalIn = amountBUSDOut + amountUSDCOut + amountUSDTOut;
    uint256 totalArthIn = swap.get_dy_underlying(1, 0, totalIn).mul(1010).div(2000);

    require(totalArthIn <= amountArthInMax, "not enough expected arth in");

    arth.transferFrom(msg.sender, me, totalArthIn);
    arth.approve(address(arthUsd), totalArthIn);
    arthUsd.deposit(totalArthIn);
    arthUsd.approve(address(swap), arthUsd.balanceOf(me));

    if (amountBUSDOut > 0) {
      uint256 arthUsdAmount = swap.get_dy_underlying(1, 0, amountBUSDOut);
      swap.exchange_underlying(0, 1, arthUsdAmount.mul(1010).div(1000), amountBUSDOut, me);
    }
    if (amountUSDCOut > 0) {
      uint256 arthUsdAmount = swap.get_dy_underlying(2, 0, amountUSDCOut);
      swap.exchange_underlying(0, 2, arthUsdAmount.mul(1010).div(1000), amountUSDCOut, me);
    }
    if (amountUSDTOut > 0) {
      uint256 arthUsdAmount = swap.get_dy_underlying(3, 0, amountUSDTOut);
      swap.exchange_underlying(0, 3, arthUsdAmount.mul(1010).div(1000), amountUSDTOut, me);
    }

    require(block.timestamp <= deadline, "swap deadline expired");
    _flush(to);
  }

  function buyARTHForExact(
    uint256 amountBUSDIn,
    uint256 amountUSDCIn,
    uint256 amountUSDTIn,
    uint256 amountARTHOutMin,
    address to,
    uint256 deadline
  ) external override {
    IStableSwap swap = IStableSwap(pool);

    if (amountBUSDIn > 0) busd.transferFrom(msg.sender, me, amountBUSDIn);
    if (amountUSDCIn > 0) usdc.transferFrom(msg.sender, me, amountUSDCIn);
    if (amountUSDTIn > 0) usdt.transferFrom(msg.sender, me, amountUSDTIn);

    busd.approve(pool, amountBUSDIn);
    usdc.approve(pool, amountUSDCIn);
    usdt.approve(pool, amountUSDTIn);

    if (amountBUSDIn > 0) {
      uint256 arthUsdAmount = swap.get_dy_underlying(1, 0, amountBUSDIn);
      swap.exchange_underlying(1, 0, amountBUSDIn, arthUsdAmount.mul(99).div(100), me);
    }
    if (amountUSDCIn > 0) {
      uint256 arthUsdAmount = swap.get_dy_underlying(2, 0, amountUSDCIn);
      swap.exchange_underlying(2, 0, amountUSDCIn, arthUsdAmount.mul(99).div(100), me);
    }
    if (amountUSDTIn > 0) {
      uint256 arthUsdAmount = swap.get_dy_underlying(3, 0, amountUSDTIn);
      swap.exchange_underlying(3, 0, amountUSDTIn, arthUsdAmount.mul(99).div(100), me);
    }

    arthUsd.withdraw(arthUsd.balanceOf(me).div(2));

    require(arth.balanceOf(me) >= amountARTHOutMin, "not enough arth out");
    require(block.timestamp <= deadline, "swap deadline expired");

    _flush(to);
  }

  function estimateARTHtoSell(
    uint256 usdcNeeded,
    uint256 usdtNeeded,
    uint256 busdNeeded
  ) external view override returns (uint256) {
    // todo this is a hack; need to do it properly
    IStableSwap swap = IStableSwap(pool);

    uint256 totalIn = usdcNeeded + usdtNeeded + busdNeeded;
    uint256 totalArthIn = swap.get_dy_underlying(1, 0, totalIn);

    // todo: need to divide by GMU
    return totalArthIn.div(2);
  }

  function estimateARTHtoBuy(
    uint256 usdcToSell,
    uint256 usdtToSell,
    uint256 busdToSell
  ) external view override returns (uint256) {
    IStableSwap swap = IStableSwap(pool);

    // todo this is a hack; need to do it properly
    uint256 totalIn = usdcToSell + usdtToSell + busdToSell;
    uint256 totalArthOut = swap.get_dy_underlying(0, 1, totalIn);

    // todo: need to divide by GMU
    return totalArthOut.div(2);
  }

  function _flush(address to) internal {
    if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
    if (arthUsd.balanceOf(me) > 0) arthUsd.transfer(to, arthUsd.balanceOf(me));
    if (usdc.balanceOf(me) > 0) usdc.transfer(to, usdc.balanceOf(me));
    if (usdt.balanceOf(me) > 0) usdt.transfer(to, usdt.balanceOf(me));
    if (busd.balanceOf(me) > 0) busd.transfer(to, busd.balanceOf(me));
  }
}
