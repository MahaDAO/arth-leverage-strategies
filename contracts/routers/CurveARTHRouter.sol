// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, IERC20WithDecimals} from "../interfaces/IERC20WithDecimals.sol";
import {IStableSwap} from "../interfaces/IStableSwap.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IEllipsisRouter} from "../interfaces/IEllipsisRouter.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract CurveARTHRouter is IEllipsisRouter {
  using SafeMath for uint256;

  address public pool;
  IERC20WithDecimals public lp;
  IStableSwap public ellipsisSwap;

  IERC20Wrapper public arthUsd;

  IERC20WithDecimals public arth;
  IERC20WithDecimals public usdc;
  IERC20WithDecimals public usdt;
  IERC20WithDecimals public busd;

  constructor(
    address _ellipsisSwap,
    address _lp,
    address _pool,
    address _arth,
    address _arthUsd,
    address _usdc,
    address _usdt,
    address _busd
  ) {
    pool = _pool;
    ellipsisSwap = IStableSwap(_ellipsisSwap);

    arthUsd = IERC20Wrapper(_arthUsd);

    lp = IERC20WithDecimals(_lp);
    arth = IERC20WithDecimals(_arth);
    usdc = IERC20WithDecimals(_usdc);
    usdt = IERC20WithDecimals(_usdt);
    busd = IERC20WithDecimals(_busd);
  }

  function sellARTHForExact(
    uint256 amountArthInMax,
    uint256 amountUSDTOut,
    uint256 amountUSDCOut,
    uint256 amountBUSDOut,
    address to,
    uint256 deadline
  ) external override {
    arth.approve(address(arthUsd), arth.balanceOf(address(this)));
    arthUsd.deposit(arth.balanceOf(address(this)));

    arthUsd.approve(address(ellipsisSwap), amountArthInMax);

    uint256[] memory depositAmounts = new uint256[](4);
    depositAmounts[0] = amountArthInMax;
    // ellipsisSwap.add_liquidity(pool, depositAmounts, 0);

    lp.approve(address(ellipsisSwap), lp.balanceOf(address(this)));

    uint256[] memory withdrawAmounts = new uint256[](4);
    withdrawAmounts[1] = amountBUSDOut;
    withdrawAmounts[2] = amountUSDCOut;
    withdrawAmounts[3] = amountUSDTOut;
    // ellipsisSwap.remove_liquidity(pool, lp.balanceOf(address(this)), withdrawAmounts);
  }

  function buyARTHForExact(
    uint256 amountUSDTIn,
    uint256 amountUSDCIn,
    uint256 amountBUSDIn,
    uint256 amountARTHOutMin,
    address to,
    uint256 deadline
  ) external override {
    usdc.approve(address(ellipsisSwap), amountUSDTIn);
    usdt.approve(address(ellipsisSwap), amountUSDCIn);
    busd.approve(address(ellipsisSwap), amountBUSDIn);

    uint256[] memory depositAmounts = new uint256[](4);
    depositAmounts[0] = amountBUSDIn;
    depositAmounts[1] = amountUSDCIn;
    depositAmounts[2] = amountUSDTIn;
    // ellipsisSwap.add_liquidity(pool, depositAmounts, 0);

    lp.approve(address(ellipsisSwap), lp.balanceOf(address(this)));
    uint256[] memory withdrawAmounts = new uint256[](4);
    withdrawAmounts[0] = amountARTHOutMin;
    // ellipsisSwap.remove_liquidity(pool, lp.balanceOf(address(this)), withdrawAmounts);

    arthUsd.withdraw(arthUsd.balanceOf(address(this)));
  }

  function estimateARTHtoSell(
    uint256 usdcNeeded,
    uint256 usdtNeeded,
    uint256 busdNeeded
  ) external view override returns (uint256) {
    // todo this is a hack; need to do it properly
    uint256 arthUsdAmount = _scalePriceByDigits(usdcNeeded, usdc.decimals(), 18) +
      _scalePriceByDigits(usdtNeeded, usdt.decimals(), 18) +
      _scalePriceByDigits(busdNeeded, busd.decimals(), 18);

    // todo: need to divide by GMU
    return arthUsdAmount.div(2);
  }

  function estimateARTHtoBuy(
    uint256 usdcToSell,
    uint256 usdtToSell,
    uint256 busdToSell
  ) external view override returns (uint256) {
    // todo this is a hack; need to do it properly
    uint256 arthUsdAmount = _scalePriceByDigits(usdcToSell, usdc.decimals(), 18) +
      _scalePriceByDigits(usdtToSell, usdt.decimals(), 18) +
      _scalePriceByDigits(busdToSell, busd.decimals(), 18);

    // todo: need to divide by GMU
    return arthUsdAmount.div(2);
  }

  function _scalePriceByDigits(
    uint256 _price,
    uint256 _answerDigits,
    uint256 _targetDigits
  ) internal pure returns (uint256) {
    // Convert the price returned by the oracle to an 18-digit decimal for use.
    uint256 price;
    if (_answerDigits >= _targetDigits) {
      // Scale the returned price value down to Liquity's target precision
      price = _price.div(10**(_answerDigits - _targetDigits));
    } else if (_answerDigits < _targetDigits) {
      // Scale the returned price value up to Liquity's target precision
      price = _price.mul(10**(_targetDigits - _answerDigits));
    }
    return price;
  }
}
