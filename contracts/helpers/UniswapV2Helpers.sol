// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashBorrower} from "../interfaces/IFlashBorrower.sol";
import {IFlashLoan} from "../interfaces/IFlashLoan.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {ILeverageStrategy} from "../interfaces/ILeverageStrategy.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import {LeverageAccount, LeverageAccountRegistry} from "../account/LeverageAccountRegistry.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {TroveHelpers} from "../helpers/TroveHelpers.sol";

contract UniswapV2Helpers {
  using SafeMath for uint256;

  IUniswapV2Router02 public uniswapRouter;
  IUniswapV2Factory public uniswapFactory;

  constructor(address _uniswapRouter) {
    uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());
  }

  function _sellARTHForExact(
    IERC20 arth,
    IERC20 tokenB,
    uint256 amountOut,
    uint256 amountInMax,
    address to
  ) internal returns (uint256) {
    if (amountOut == 0) return 0;
    arth.approve(address(uniswapRouter), amountInMax);

    address[] memory path = new address[](2);
    path[0] = address(arth);
    path[1] = address(tokenB);

    uint256[] memory amountsOut = uniswapRouter.swapTokensForExactTokens(
      amountOut,
      amountInMax,
      path,
      to,
      block.timestamp
    );

    return amountsOut[amountsOut.length - 1];
  }

  function _buyExactARTH(
    IERC20 arth,
    IERC20 tokenB,
    uint256 amountOut,
    uint256 amountInMax,
    address to
  ) internal returns (uint256) {
    if (amountOut == 0) return 0;
    tokenB.approve(address(uniswapRouter), amountInMax);

    address[] memory path = new address[](2);
    path[0] = address(tokenB);
    path[1] = address(arth);

    uint256[] memory amountsOut = uniswapRouter.swapTokensForExactTokens(
      amountOut,
      amountInMax,
      path,
      to,
      block.timestamp
    );

    return amountsOut[amountsOut.length - 1];
  }

  function estimateARTHtoSell(
    IERC20 arth,
    IERC20 tokenB,
    uint256 tokenBNeeded
  ) public view returns (uint256 arthToSell) {
    if (tokenBNeeded == 0) return 0;

    address[] memory path = new address[](2);
    path[0] = address(arth);
    path[1] = address(tokenB);

    uint256[] memory amountsOut = uniswapRouter.getAmountsIn(tokenBNeeded, path);
    arthToSell = amountsOut[0];
  }

  function estimateARTHtoBuy(
    IERC20 arth,
    IERC20 tokenB,
    uint256 arthNeeded
  ) public view returns (uint256 maticToSell) {
    if (arthNeeded == 0) return 0;

    address[] memory path = new address[](2);
    path[0] = address(tokenB);
    path[1] = address(arth);

    uint256[] memory amountsOut = uniswapRouter.getAmountsIn(arthNeeded, path);
    maticToSell = amountsOut[0];
  }
}
