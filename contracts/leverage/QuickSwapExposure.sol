// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IFlashBorrower} from "../interfaces/IFlashBorrower.sol";
import {IFlashLoan} from "../interfaces/IFlashLoan.sol";
import {ILeverageStrategy} from "../interfaces/ILeverageStrategy.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {LeverageAccount, LeverageAccountRegistry} from "../account/LeverageAccountRegistry.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {TroveHelpers} from "../helpers/TroveHelpers.sol";
import {CurveHelpers} from "../helpers/CurveHelpers.sol";
import {IPrincipalCollateralRecorder} from "../interfaces/IPrincipalCollateralRecorder.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";

contract QuickSwapExposure is TroveHelpers, IFlashBorrower, ILeverageStrategy, CurveHelpers {
  using SafeMath for uint256;

  address public borrowerOperations;
  address public controller;

  ITroveManager public troveManager;
  IPriceFeed public priceFeed;

  IERC20 public arth;
  IERC20 public usdt;
  IERC20 public usdc;
  IERC20 public rewardToken;

  IFlashLoan public flashLoan;
  LeverageAccountRegistry public accountRegistry;
  address public recorder;

  IERC20 public lp;

  IERC20Wrapper public arthUsd;
  IERC20Wrapper public stakingWrapper;

  IUniswapV2Router02 public uniswapRouter;
  IUniswapV2Factory public uniswapFactory;

  address private me;

  bytes4 private constant RECORD_PRINCIPAL_SELECTOR =
    bytes4(keccak256("recordPrincipalCollateral(string,uint256,uint256,uint256)"));

  constructor(
    address _flashloan,
    address _controller,
    address _arth,
    address _usdc,
    address _usdt,
    address _rewardToken,
    address _curveRouter,
    address _clp,
    address _arthUsd,
    address _uniswapRouter
  ) CurveHelpers(_curveRouter, _clp) {
    controller = _controller;
    usdt = IERC20(_usdt);
    arth = IERC20(_arth);
    usdc = IERC20(_usdc);
    rewardToken = IERC20(_rewardToken);
    flashLoan = IFlashLoan(_flashloan);
    arthUsd = IERC20Wrapper(_arthUsd);

    me = address(this);

    uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());
    lp = IERC20(uniswapFactory.getPair(_usdc, _usdt));
  }

  function init(
    address _borrowerOperations,
    address _troveManager,
    address _priceFeed,
    address _arthUsd,
    address _recorder,
    address _stakingWrapper,
    address _accountRegistry
  ) public {
    require(borrowerOperations == address(0), "already initialized");
    borrowerOperations = _borrowerOperations;
    troveManager = ITroveManager(_troveManager);
    uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());
    priceFeed = IPriceFeed(_priceFeed);
    arthUsd = IERC20Wrapper(_arthUsd);
    stakingWrapper = IERC20Wrapper(_stakingWrapper);
    accountRegistry = LeverageAccountRegistry(_accountRegistry);

    recorder = _recorder;
  }

  function getAccount(address who) public view returns (LeverageAccount) {
    return accountRegistry.accounts(who);
  }

  function test(
    uint256 amount,
    uint256 amountInMax,
    uint256[] memory borrowedCollateral
  ) public {
    arth.transferFrom(msg.sender, me, amount);

    _sellARTHusdForExact(
      arth,
      arthUsd,
      amountInMax,
      borrowedCollateral[0], // usdc
      borrowedCollateral[1] // usdt
    );

    _flush(msg.sender);
  }

  function openPosition(
    uint256[] memory finalExposure,
    uint256[] memory principalCollateral,
    uint256 minExpectedCollateralRatio,
    uint256 maxBorrowingFee
  ) external override {
    // take the principal
    usdc.transferFrom(msg.sender, address(this), principalCollateral[0]);

    // estimate how much we should flashloan based on how much we want to borrow
    uint256 flashloanAmount = estimateAmountToFlashloanBuy(finalExposure, principalCollateral);

    // LeverageAccount acct = getAccount(msg.sender);
    // bytes memory principalCollateralData = abi.encodeWithSelector(
    //   RECORD_PRINCIPAL_SELECTOR,
    //   "BUSD-USDC-ALP-S",
    //   principalCollateral[0],
    //   0,
    //   0
    // );
    // acct.callFn(recorder, principalCollateralData);

    bytes memory flashloanData = abi.encode(
      msg.sender,
      uint256(0), // action = 0 -> open loan
      minExpectedCollateralRatio,
      maxBorrowingFee,
      finalExposure,
      principalCollateral
    );

    flashLoan.flashLoan(address(this), flashloanAmount, flashloanData);
    _flush(msg.sender);
  }

  function closePosition(uint256[] memory minExpectedCollateral) external override {
    //   bytes memory flashloanData = abi.encode(
    //     msg.sender,
    //     uint256(1), // action = 0 -> close loan
    //     uint256(0),
    //     uint256(0),
    //     minExpectedCollateral,
    //     minExpectedCollateral
    //   );
    //   // need to make this MEV resistant
    //   uint256 flashloanAmount = troveManager.getTroveDebt(address(getAccount(msg.sender)));
    //   flashLoan.flashLoan(address(this), flashloanAmount.add(10e18), flashloanData);
    //   _flush(msg.sender);
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
      uint256 minExpectedCollateralRatio,
      uint256 maxBorrowingFee,
      uint256[] memory borrowedCollateral,
      uint256[] memory minCollateral
    ) = abi.decode(data, (address, uint256, uint256, uint256, uint256[], uint256[]));

    // open or close the loan position
    if (action == 0) {
      _onFlashloanOpenPosition(
        who,
        flashloanAmount,
        borrowedCollateral,
        minExpectedCollateralRatio,
        maxBorrowingFee
      );
    }
    // else _onFlashloanClosePosition(who, flashloanAmount, minCollateral);

    return keccak256("FlashMinter.onFlashLoan");
  }

  function _onFlashloanOpenPosition(
    address who,
    uint256 flashloanAmount,
    uint256[] memory finalExposure,
    uint256 minExpectedCollateralRatio,
    uint256 maxBorrowingFee
  ) internal {
    LeverageAccount acct = getAccount(who);

    // 1: sell arth for collateral
    _sellARTHusdForExact(
      arth,
      arthUsd,
      flashloanAmount,
      finalExposure[0], // usdc
      finalExposure[1] // usdt
    );

    // 2. LP all the collateral
    // 3. Stake and tokenize
    // 4: Send the collateral to the leverage account
    uint256 collateralAmount = _lpAndStake(acct);

    // 5: open loan using the collateral
    openLoan(
      acct,
      borrowerOperations,
      maxBorrowingFee, // borrowing fee
      flashloanAmount, // debt + liquidation reserve
      collateralAmount, // collateral
      address(0), // upperHint,
      address(0), // lowerHint,
      address(0), // frontEndTag,
      arth,
      stakingWrapper
    );

    // 6. check if we met the min leverage conditions
    require(_getTroveCR(address(acct)) >= minExpectedCollateralRatio, "min cr not met");

    // 7. payback the loan..
    arth.approve(address(flashLoan), flashloanAmount);
    require(arth.balanceOf(me) >= flashloanAmount, "not enough arth for flashload");
  }

  // function _onFlashloanClosePosition(
  //   address who,
  //   uint256 flashloanAmount,
  //   uint256[] memory minCollateral
  // ) internal {
  //   LeverageAccount acct = getAccount(who);

  //   // 1. send the flashloaned arth to the account
  //   arth.transfer(address(acct), flashloanAmount);

  //   // 2. use the flashloan'd ARTH to payback the debt and close the loan
  //   closeLoan(acct, controller, borrowerOperations, flashloanAmount, arth, stakingWrapper);

  //   // 3. get the collateral and swap back to arth to back the loan
  //   _unStakeAndWithdrawLP();
  //   _buyCollateralForARTH(flashloanAmount, minCollateral);

  //   require(usdc.balanceOf(me) >= minCollateral[0], "not enough usdc");
  //   require(usdt.balanceOf(me) >= minCollateral[1], "not enough usdt");

  //   // 4. payback the loan..
  //   arth.approve(address(flashLoan), flashloanAmount);
  //   require(arth.balanceOf(me) >= flashloanAmount, "not enough arth for flashload");
  // }

  function _lpAndStake(LeverageAccount acct) internal returns (uint256) {
    // 2. LP all the collateral
    usdc.approve(address(uniswapRouter), usdc.balanceOf(me));
    usdt.approve(address(uniswapRouter), usdt.balanceOf(me));

    uniswapRouter.addLiquidity(
      address(usdc),
      address(usdt),
      usdc.balanceOf(me),
      usdt.balanceOf(me),
      0,
      0,
      me,
      block.timestamp
    );

    // 3. Stake and tokenize
    uint256 collateralAmount = lp.balanceOf(me);
    lp.approve(address(stakingWrapper), collateralAmount);
    stakingWrapper.deposit(collateralAmount);

    // 4: send the collateral to the leverage account
    if (collateralAmount > 0) stakingWrapper.transfer(address(acct), collateralAmount);
    return collateralAmount;
  }

  // function _unStakeAndWithdrawLP() internal {
  //   // 1. unstake and un-tokenize
  //   uint256 collateralAmount = stakingWrapper.balanceOf(me);
  //   stakingWrapper.withdraw(collateralAmount);

  //   // 2. remove from LP
  //   lp.approve(address(uniswapRouter), lp.balanceOf(me));
  //   uniswapRouter.removeLiquidity(
  //     address(usdc),
  //     address(usdt),
  //     lp.balanceOf(me),
  //     0, // amountAMin
  //     0, // amountBMin
  //     me,
  //     block.timestamp
  //   );
  // }

  function _buyCollateralForARTH(uint256 amountToSell, uint256[] memory minCollateral) internal {
    // _sellARTHusdForExact(
    //   arth,
    //   arthUsd,
    //   amountToSell,
    //   minCollateral[0], // busd
    //   minCollateral[1], // usdc
    //   0 // usdt
    // );
  }

  function estimateAmountToFlashloanBuy(
    uint256[] memory finalExposure,
    uint256[] memory principalCollateral
  ) public view returns (uint256) {
    // if (finalExposure[0] < principalCollateral) {
    // we have enough usdt
    return estimateARTHtoBuy(address(usdt), address(usdc), 0, finalExposure[1]);
    // }
    // return estimateARTHtoBuy(address(usdt), address(usdc), finalExposure[0], finalExposure[1]);
  }

  function _getTroveCR(address who) internal returns (uint256) {
    uint256 price = priceFeed.fetchPrice();
    return getTroveCR(who, price);
  }

  function getTroveCR(address who, uint256 price) public view returns (uint256) {
    uint256 debt = troveManager.getTroveDebt(who);
    uint256 coll = troveManager.getTroveColl(who);
    return coll.mul(price).div(debt);
  }

  function _flush(address to) internal {
    if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
    if (arthUsd.balanceOf(me) > 0) arthUsd.transfer(to, arthUsd.balanceOf(me));
    if (usdc.balanceOf(me) > 0) usdc.transfer(to, usdc.balanceOf(me));
    if (usdt.balanceOf(me) > 0) usdt.transfer(to, usdt.balanceOf(me));
    // if (rewardToken.balanceOf(me) > 0) rewardToken.transfer(to, rewardToken.balanceOf(me));
  }
}
