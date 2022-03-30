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
    uint256 amountUSDTOut,
    uint256 amountUSDCOut,
    uint256 amountBUSDOut,
    address to,
    uint256 deadline
  ) external override {
    arth.transferFrom(msg.sender, me, amountArthInMax);
    arth.approve(address(arthUsd), amountArthInMax);
    arthUsd.deposit(amountArthInMax);

    uint256 arthUsdAmount = arthUsd.balanceOf(me);
    arthUsd.approve(address(zap), arthUsdAmount);

    uint256[4] memory depositAmounts = [arthUsdAmount, 0, 0, 0];
    uint256 expectedIn = calc_token_amount(depositAmounts, true).mul(990).div(1000); // 1% slippage
    zap.add_liquidity(pool, depositAmounts, expectedIn);

    lp.approve(address(zap), lp.balanceOf(me));

    uint256[4] memory withdrawAmounts = [amountBUSDOut, amountUSDCOut, amountUSDTOut, 0];
    uint256 expectedOut = calc_token_amount(withdrawAmounts, false).mul(1010).div(1000); // 1% slippage
    zap.remove_liquidity_imbalance(pool, withdrawAmounts, expectedOut);

    require(block.timestamp <= deadline, "swap deadline expired");

    _flush(to);
  }

  function test(
    uint256 amountArthInMax,
    uint256 amountUSDTOut,
    uint256 amountUSDCOut,
    uint256 amountBUSDOut,
    address to,
    uint256 deadline
  ) external {
    lp.transferFrom(msg.sender, me, amountArthInMax);
    lp.approve(address(zap), lp.balanceOf(me));

    uint256[4] memory withdrawAmounts = [0, amountBUSDOut, amountUSDCOut, amountUSDTOut];
    uint256 expectedOut = calc_token_amount(withdrawAmounts, false).mul(1010).div(1000); // 1% slippage
    zap.remove_liquidity_imbalance(pool, withdrawAmounts, expectedOut);

    require(block.timestamp <= deadline, "swap deadline expired");

    _flush(to);
  }

  function buyARTHForExact(
    uint256 amountUSDTIn,
    uint256 amountUSDCIn,
    uint256 amountBUSDIn,
    uint256 amountARTHOutMin,
    address to,
    uint256 deadline
  ) external override {
    usdc.transferFrom(msg.sender, me, amountUSDTIn);
    usdt.transferFrom(msg.sender, me, amountUSDCIn);
    busd.transferFrom(msg.sender, me, amountBUSDIn);

    usdc.approve(address(zap), amountUSDTIn);
    usdt.approve(address(zap), amountUSDCIn);
    busd.approve(address(zap), amountBUSDIn);

    uint256[4] memory depositAmounts = [amountBUSDIn, amountUSDCIn, amountUSDTIn, 0];
    uint256 expectedIn = calc_token_amount(depositAmounts, false).mul(1010).div(1000); // 1% slippage
    zap.add_liquidity(pool, depositAmounts, expectedIn);

    lp.approve(address(zap), lp.balanceOf(address(this)));

    uint256[4] memory withdrawAmounts = [amountARTHOutMin, 0, 0, 0];
    uint256 expectedOut = calc_token_amount(withdrawAmounts, false).mul(1010).div(1000); // 1% slippage
    zap.remove_liquidity_imbalance(pool, withdrawAmounts, expectedOut);

    arthUsd.withdraw(arthUsd.balanceOf(address(this)));

    require(arthUsd.balanceOf(me) >= amountARTHOutMin, "not enough arth out");
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

    uint256 arthUsdAmount = swap.get_dy_underlying(1, 0, busdNeeded) +
      swap.get_dy_underlying(2, 0, usdcNeeded) +
      swap.get_dy_underlying(3, 0, usdtNeeded);

    // todo: need to divide by GMU
    return arthUsdAmount.div(2);
  }

  function estimateARTHtoBuy(
    uint256 usdcToSell,
    uint256 usdtToSell,
    uint256 busdToSell
  ) external view override returns (uint256) {
    IStableSwap swap = IStableSwap(pool);

    // todo this is a hack; need to do it properly
    uint256 arthUsdAmount = swap.get_dy_underlying(0, 1, usdcToSell) +
      swap.get_dy_underlying(0, 2, usdtToSell) +
      swap.get_dy_underlying(0, 3, busdToSell);

    // todo: need to divide by GMU
    return arthUsdAmount.div(2);
  }

  function calc_token_amount(uint256[4] memory amounts, bool isDeposit)
    public
    view
    returns (uint256)
  {
    return zap.calc_token_amount(pool, amounts, isDeposit);
  }

  function calc_withdraw_one_coin(uint256 burnAmount, int128 i) public view returns (uint256) {
    return zap.calc_withdraw_one_coin(pool, burnAmount, i);
  }

  function _flush(address to) internal {
    if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
    if (usdc.balanceOf(me) > 0) usdc.transfer(to, usdc.balanceOf(me));
    if (usdt.balanceOf(me) > 0) usdt.transfer(to, usdt.balanceOf(me));
    if (busd.balanceOf(me) > 0) busd.transfer(to, busd.balanceOf(me));
    if (lp.balanceOf(me) > 0) lp.transfer(to, lp.balanceOf(me));
  }
}
