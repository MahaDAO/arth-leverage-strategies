// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashBorrower} from "../interfaces/IFlashBorrower.sol";
import {IFlashLoan} from "../interfaces/IFlashLoan.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {ILeverageStrategy} from "../interfaces/ILeverageStrategy.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {LeverageAccount, LeverageAccountRegistry} from "../account/LeverageAccountRegistry.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {TroveHelpers} from "../helpers/TroveHelpers.sol";

contract WMaticExposure is IFlashBorrower, TroveHelpers {
  using SafeMath for uint256;

  event OpenPosition(uint256 amount, address who);

  address public borrowerOperations;
  address public controller;
  ITroveManager public troveManager;

  IERC20 public immutable arth;
  IERC20 public immutable usdc;
  IERC20 public immutable wmatic;
  IFlashLoan public flashLoan;
  LeverageAccountRegistry public accountRegistry;
  IUniswapV2Router02 public immutable uniswapRouter;

  address private me;

  event Where(address who, uint256 line);

  constructor(
    address _flashloan,
    address _arth,
    address _wmatic,
    address _usdc,
    address _uniswapRouter,
    address _borrowerOperations,
    address _controller,
    address _accountRegistry,
    address _troveManager
  ) {
    flashLoan = IFlashLoan(_flashloan);

    arth = IERC20(_arth);
    usdc = IERC20(_usdc);
    wmatic = IERC20(_wmatic);
    uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    borrowerOperations = _borrowerOperations;
    troveManager = ITroveManager(_troveManager);
    accountRegistry = LeverageAccountRegistry(_accountRegistry);
    controller = _controller;

    me = address(this);
  }

  function getAccount(address who) public view returns (LeverageAccount) {
    return accountRegistry.accounts(who);
  }

  function openPosition(
    uint256 borrowedCollateral,
    uint256 principalCollateral,
    uint256 minExposure,
    uint256 maxBorrowingFee,
    address upperHint,
    address lowerHint,
    address frontEndTag
  ) external {
    // take the principal
    wmatic.transferFrom(msg.sender, address(this), principalCollateral);

    // estimate how much we should flashloan based on how much we want to borrow
    uint256 flashloanAmount = estimateARTHtoSell(borrowedCollateral);

    bytes memory flashloanData = abi.encode(
      msg.sender,
      uint256(0), // action = 0 -> open loan
      maxBorrowingFee,
      principalCollateral,
      minExposure,
      upperHint,
      lowerHint,
      frontEndTag
    );

    arth.approve(address(flashLoan), flashloanAmount);
    flashLoan.flashLoan(address(this), flashloanAmount, flashloanData);
    flush(msg.sender);
  }

  function closePosition() external {
    bytes memory flashloanData = abi.encode(
      msg.sender,
      uint256(1), // action = 0 -> close loan
      uint256(0),
      uint256(0),
      uint256(0),
      address(0),
      address(0),
      address(0)
    );

    // need to make this MEV resistant

    uint256 flashloanAmount = troveManager.getTroveDebt(address(getAccount(msg.sender)));

    arth.approve(address(flashLoan), flashloanAmount);
    flashLoan.flashLoan(address(this), flashloanAmount, flashloanData);
    flush(msg.sender);
  }

  function onFlashLoan(
    address initiator,
    uint256 flashloanAmount,
    uint256 fee,
    bytes calldata data
  ) external override returns (bytes32) {
    require(msg.sender == address(flashLoan), "untrusted lender");
    require(initiator == address(this), "not contract");

    // decode the data
    (
      address who,
      uint256 action,
      uint256 maxBorrowingFee,
      uint256 principalCollateral,
      uint256 minExposure,
      address upperHint,
      address lowerHint,
      address frontEndTag
    ) = abi.decode(data, (address, uint256, uint256, uint256, uint256, address, address, address));

    // // open or close the loan position
    if (action == 0) {
      onFlashloanOpenPosition(
        who,
        flashloanAmount,
        principalCollateral,
        maxBorrowingFee,
        minExposure,
        upperHint,
        lowerHint,
        frontEndTag
      );
    } else onFlashloanClosePosition(who, flashloanAmount);

    return keccak256("FlashMinter.onFlashLoan");
  }

  function onFlashloanOpenPosition(
    address who,
    uint256 flashloanAmount,
    uint256 principalCollateral,
    uint256 maxBorrowingFee,
    uint256 minExposure,
    address upperHint,
    address lowerHint,
    address frontEndTag
  ) internal {
    LeverageAccount acct = getAccount(who);

    // 1: sell arth for collateral
    uint256 initCollateralAmount = wmatic.balanceOf(address(acct)).add(principalCollateral);
    if (initCollateralAmount < minExposure) {
      uint256 wmaticNeeded = minExposure.sub(initCollateralAmount);
      sellARTHForExact(wmaticNeeded, flashloanAmount, address(acct));
    }

    // 2: send the collateral to the leverage account
    if (initCollateralAmount > 0) wmatic.transfer(address(acct), initCollateralAmount);

    // 3: open loan using the collateral
    uint256 totalCollateralAmount = wmatic.balanceOf(address(acct));
    // openLoan(
    //   borrowerOperations,
    //   maxBorrowingFee, // borrowing fee
    //   flashloanAmount.add(10 * 1e18), // debt + liquidation reserve
    //   totalCollateralAmount, // collateral
    //   upperHint,
    //   lowerHint,
    //   frontEndTag
    // );

    // over here we will have a open loan with collateral and leverage account would've
    // send us back the minted arth
    // 4. payback the loan..

    // 5. check if we met the min leverage conditions
    // require(troveManager.getTroveDebt(address(acct)) >= minExposure, "min exposure not met");
  }

  function onFlashloanClosePosition(address who, uint256 flashloanAmount) internal {
    LeverageAccount acct = getAccount(who);

    // 1. send the flashloaned arth to the account
    arth.transfer(address(acct), flashloanAmount);

    // 2. use the flashloan'd ARTH to payback the debt and close the loan
    closeLoan(acct, controller, borrowerOperations, flashloanAmount, arth, wmatic);

    // 3. get the collateral and swap back to arth to back the loan
    uint256 totalCollateralAmount = wmatic.balanceOf(address(this));
    uint256 arthBal = arth.balanceOf(address(this));
    uint256 pendingArth = flashloanAmount.sub(arthBal);

    buyExactARTH(pendingArth, totalCollateralAmount, address(this));

    // 4. payback the loan..
  }

  function sellARTHForExact(
    uint256 amountOut,
    uint256 amountInMax,
    address to
  ) internal returns (uint256) {
    if (amountOut == 0) return 0;

    arth.approve(address(uniswapRouter), amountInMax);

    address[] memory path = new address[](3);
    path[0] = address(arth);
    path[1] = address(usdc);
    path[2] = address(wmatic);

    uint256[] memory amountsOut = uniswapRouter.swapTokensForExactTokens(
      amountOut,
      amountInMax,
      path,
      to,
      block.timestamp
    );

    return amountsOut[amountsOut.length - 1];
  }

  function buyExactARTH(
    uint256 amountOut,
    uint256 amountInMax,
    address to
  ) internal returns (uint256) {
    if (amountOut == 0) return 0;
    wmatic.approve(address(uniswapRouter), amountInMax);

    address[] memory path = new address[](3);
    path[0] = address(wmatic);
    path[1] = address(usdc);
    path[2] = address(arth);

    uint256[] memory amountsOut = uniswapRouter.swapTokensForExactTokens(
      amountOut,
      amountInMax,
      path,
      to,
      block.timestamp
    );

    return amountsOut[amountsOut.length - 1];
  }

  function estimateARTHtoSell(uint256 maticNeeded) public view returns (uint256 arthToSell) {
    if (maticNeeded == 0) return 0;

    address[] memory path = new address[](3);
    path[0] = address(arth);
    path[1] = address(usdc);
    path[2] = address(wmatic);

    uint256[] memory amountsOut = uniswapRouter.getAmountsIn(maticNeeded, path);
    arthToSell = amountsOut[0];
  }

  function estimateARTHtoBuy(uint256 arthNeeded) public view returns (uint256 maticToSell) {
    if (arthNeeded == 0) return 0;

    address[] memory path = new address[](3);
    path[0] = address(wmatic);
    path[1] = address(usdc);
    path[2] = address(arth);

    uint256[] memory amountsOut = uniswapRouter.getAmountsIn(arthNeeded, path);
    maticToSell = amountsOut[0];
  }

  function flush(address to) internal {
    if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
    if (usdc.balanceOf(me) > 0) usdc.transfer(to, usdc.balanceOf(me));
    if (wmatic.balanceOf(me) > 0) wmatic.transfer(to, wmatic.balanceOf(me));
  }
}
