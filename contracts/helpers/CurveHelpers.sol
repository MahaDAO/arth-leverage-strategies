// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface CurveRouter {
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

  function exchange_underlying(
    address _pool,
    int128 _i,
    int128 _j,
    uint256 _dx,
    uint256 _min_dy,
    address _receiver,
    bool _use_underlying
  ) external;
}

interface IERC20WithDeciamls is IERC20 {
  function decimals() external view returns (uint256);
}

contract CurveHelpers {
  using SafeMath for uint256;

  CurveRouter public curveRouter;
  IERC20 public clp;

  constructor(address _router, address _clp) {
    clp = IERC20(_clp);
    curveRouter = CurveRouter(_router);
  }

  function _sellARTHusdForExact(
    IERC20 arth,
    IERC20Wrapper arthUsd,
    uint256 amountInMax,
    uint256 amountUSDCOut,
    uint256 amountUSDTOut
  ) internal {
    arth.approve(address(arthUsd), amountInMax);

    arthUsd.deposit(amountInMax);
    arthUsd.approve(address(curveRouter), arthUsd.balanceOf(address(this)));

    if (amountUSDCOut > 0)
      curveRouter.exchange_underlying(
        address(clp),
        0,
        2,
        arthUsd.balanceOf(address(this)).div(2),
        amountUSDCOut,
        address(this),
        true
      );

    if (amountUSDTOut > 0)
      curveRouter.exchange_underlying(
        address(clp),
        0,
        3,
        arthUsd.balanceOf(address(this)), //.div(2),
        amountUSDTOut,
        address(this),
        true
      );
  }

  function _buyARTHusdFromExact(
    IERC20Wrapper arthUsd,
    IERC20 usdc,
    IERC20 usdt,
    uint256 amountUSDCInMax,
    uint256 amountUSDTInMax,
    uint256 amountOutMin
  ) internal {
    usdc.approve(address(curveRouter), amountUSDCInMax);
    usdt.approve(address(curveRouter), amountUSDTInMax);

    curveRouter.exchange_underlying(
      address(clp),
      2,
      0,
      amountUSDCInMax,
      amountOutMin.div(2),
      address(this),
      true
    );

    curveRouter.exchange_underlying(
      address(clp),
      3,
      0,
      amountUSDTInMax,
      amountOutMin.div(2),
      address(this),
      true
    );

    arthUsd.withdraw(arthUsd.balanceOf(address(this)));
  }

  function estimateARTHtoSell(
    address usdc,
    address usdt,
    uint256 usdcNeeded,
    uint256 usdtNeeded
  ) public view returns (uint256 arthToSell) {
    uint256 arthUsdAmount = _scalePriceByDigits(
      usdcNeeded,
      IERC20WithDeciamls(usdc).decimals(),
      18
    ) + _scalePriceByDigits(usdtNeeded, IERC20WithDeciamls(usdt).decimals(), 18);

    return arthUsdAmount.div(2);
  }

  function estimateARTHtoBuy(
    address usdc,
    address usdt,
    uint256 usdcNeeded,
    uint256 usdtNeeded
  ) public view returns (uint256 maticToSell) {
    uint256 arthUsdAmount = _scalePriceByDigits(
      usdcNeeded,
      IERC20WithDeciamls(usdc).decimals(),
      18
    ) + _scalePriceByDigits(usdtNeeded, IERC20WithDeciamls(usdt).decimals(), 18);

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
