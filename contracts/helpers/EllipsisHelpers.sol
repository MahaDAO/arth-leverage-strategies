// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface EllipsisRouter {
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

interface IERC20WithDeciamls is IERC20 {
  function decimals() external view returns (uint256);
}

contract EllipsisHelpers {
  using SafeMath for uint256;

  address public pool;
  IERC20 public elp;
  EllipsisRouter public ellipsisRouter;

  constructor(
    address _ellipsisRouter,
    address _elp,
    address _pool
  ) {
    pool = _pool;
    elp = IERC20(_elp);
    ellipsisRouter = EllipsisRouter(_ellipsisRouter);
  }

  function _sellARTHusdForExact(
    IERC20 arth,
    IERC20Wrapper arthUsd,
    uint256 amountInMax,
    uint256 amountAOut,
    uint256 amountBOut,
    uint256 amountCOut
  ) internal {
    arth.approve(address(arthUsd), arth.balanceOf(address(this)));
    arthUsd.deposit(arth.balanceOf(address(this)));

    arthUsd.approve(address(ellipsisRouter), amountInMax);

    uint256[] memory depositAmounts = new uint256[](4);
    depositAmounts[0] = amountInMax;
    ellipsisRouter.add_liquidity(pool, depositAmounts, 0);

    elp.approve(address(ellipsisRouter), elp.balanceOf(address(this)));

    uint256[] memory withdrawAmounts = new uint256[](4);
    withdrawAmounts[1] = amountAOut;
    withdrawAmounts[2] = amountBOut;
    withdrawAmounts[3] = amountCOut;
    ellipsisRouter.remove_liquidity(pool, elp.balanceOf(address(this)), withdrawAmounts);
  }

  function _buyARTHusdForExact(
    IERC20Wrapper arthUsd,
    IERC20 tokenA,
    IERC20 tokenB,
    IERC20 tokenC,
    uint256 amountAIn,
    uint256 amountBIn,
    uint256 amountCIn,
    uint256 amountOutMin
  ) internal {
    tokenA.approve(address(ellipsisRouter), amountAIn);
    tokenB.approve(address(ellipsisRouter), amountBIn);
    tokenC.approve(address(ellipsisRouter), amountCIn);

    uint256[] memory depositAmounts = new uint256[](4);
    depositAmounts[0] = amountAIn;
    depositAmounts[1] = amountBIn;
    depositAmounts[2] = amountCIn;
    ellipsisRouter.add_liquidity(pool, depositAmounts, 0);

    elp.approve(address(ellipsisRouter), elp.balanceOf(address(this)));
    uint256[] memory withdrawAmounts = new uint256[](4);
    withdrawAmounts[0] = amountOutMin;
    ellipsisRouter.remove_liquidity(pool, elp.balanceOf(address(this)), withdrawAmounts);

    arthUsd.withdraw(arthUsd.balanceOf(address(this)));
  }

  function estimateARTHusdtoSell(
    address tokenA,
    address tokenB,
    uint256 tokenANeeded,
    uint256 tokenBNeeded
  ) public view returns (uint256 arthToSell) {
    uint256 arthUsdAmount = _scalePriceByDigits(
      tokenANeeded,
      IERC20WithDeciamls(tokenA).decimals(),
      18
    ) + _scalePriceByDigits(tokenBNeeded, IERC20WithDeciamls(tokenB).decimals(), 18);

    return arthUsdAmount.div(2);
  }

  function estimateARTHusdtoBuy(
    address tokenA,
    address tokenB,
    uint256 tokenANeeded,
    uint256 tokenBNeeded
  ) public view returns (uint256 maticToSell) {
    return
      _scalePriceByDigits(tokenANeeded, IERC20WithDeciamls(tokenA).decimals(), 18) +
      _scalePriceByDigits(tokenBNeeded, IERC20WithDeciamls(tokenB).decimals(), 18);
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
