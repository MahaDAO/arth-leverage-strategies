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
import {EllipsisHelpers} from "../helpers/EllipsisHelpers.sol";
import {UniswapV2Helpers} from "../helpers/UniswapV2Helpers.sol";
import {IPrincipalCollateralRecorder} from "../interfaces/IPrincipalCollateralRecorder.sol";

contract LPExpsoureSingleCollat is
  IFlashBorrower,
  ILeverageStrategy,
  TroveHelpers,
  UniswapV2Helpers,
  EllipsisHelpers
{
  using SafeMath for uint256;

  address public borrowerOperations;
  address public controller;

  ITroveManager public troveManager;
  IPriceFeed public priceFeed;

  IERC20 public arth;
  IERC20 public busd;
  IERC20 public usdc;
  IERC20 public rewardToken;

  IFlashLoan public flashLoan;
  LeverageAccountRegistry public accountRegistry;
  address public recorder;

  IERC20 public lp;

  IERC20Wrapper public arthUsd;
  IERC20Wrapper public stakingWrapper;

  address private me;

  bytes4 private constant RECORD_PRINCIPAL_SELECTOR =
    bytes4(keccak256("recordPrincipalCollateral(string,uint256,uint256,uint256)"));

  constructor(
    address _flashloan,
    address _controller,
    address _usdc,
    address _busd,
    address _rewardToken,
    address _ellipsisRouter,
    address _elp,
    address _epool,
    address _stakingWrapper,
    address _accountRegistry,
    address _uniswapRouter
  ) EllipsisHelpers(_ellipsisRouter, _elp, _epool) UniswapV2Helpers(_uniswapRouter) {
    accountRegistry = LeverageAccountRegistry(_accountRegistry);

    controller = _controller;
    busd = IERC20(_busd);
    flashLoan = IFlashLoan(_flashloan);
    usdc = IERC20(_usdc);
    rewardToken = IERC20(_rewardToken);
    stakingWrapper = IERC20Wrapper(_stakingWrapper);

    me = address(this);

    uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());
    lp = IERC20(uniswapFactory.getPair(_usdc, _busd));
  }

  function init(
    address _borrowerOperations,
    address _troveManager,
    address _priceFeed,
    address _recorder
  ) public {
    borrowerOperations = _borrowerOperations;
    troveManager = ITroveManager(_troveManager);

    arth = troveManager.lusdToken();
    uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());
    priceFeed = IPriceFeed(_priceFeed);
    recorder = _recorder;
  }

  function getAccount(address who) public view returns (LeverageAccount) {
    return accountRegistry.accounts(who);
  }

  function openPosition(
    uint256[] memory borrowedCollateral,
    uint256[] memory principalCollateral,
    uint256 minExpectedCollateralRatio,
    uint256 maxBorrowingFee
  ) external override {
    // take the principal
    usdc.transferFrom(msg.sender, address(this), principalCollateral[0]);

    // estimate how much we should flashloan based on how much we want to borrow
    uint256 flashloanAmount = estimateAmountToFlashloanBuy(borrowedCollateral);

    LeverageAccount acct = getAccount(msg.sender);
    bytes memory principalCollateralData = abi.encodeWithSelector(
      RECORD_PRINCIPAL_SELECTOR,
      "BUSD-USDC-ALP-S",
      principalCollateral[0],
      0,
      0
    );
    acct.callFn(recorder, principalCollateralData);

    bytes memory flashloanData = abi.encode(
      msg.sender,
      uint256(0), // action = 0 -> open loan
      minExpectedCollateralRatio,
      maxBorrowingFee,
      borrowedCollateral,
      principalCollateral
    );

    flashLoan.flashLoan(address(this), flashloanAmount, flashloanData);
    _flush(msg.sender);
  }

  function closePosition(uint256[] memory minExpectedCollateral) external override {
    bytes memory flashloanData = abi.encode(
      msg.sender,
      uint256(1), // action = 0 -> close loan
      uint256(0),
      uint256(0),
      minExpectedCollateral,
      minExpectedCollateral
    );

    // need to make this MEV resistant
    uint256 flashloanAmount = troveManager.getTroveDebt(address(getAccount(msg.sender)));
    flashLoan.flashLoan(address(this), flashloanAmount.add(10e18), flashloanData);
    _flush(msg.sender);
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
    } else _onFlashloanClosePosition(who, flashloanAmount, minCollateral);

    return keccak256("FlashMinter.onFlashLoan");
  }

  function _onFlashloanOpenPosition(
    address who,
    uint256 flashloanAmount,
    uint256[] memory borrowedCollateral,
    uint256 minExpectedCollateralRatio,
    uint256 maxBorrowingFee
  ) internal {
    LeverageAccount acct = getAccount(who);

    // 1: sell arth for collateral
    _sellCollateralForARTH(borrowedCollateral);

    // 2. LP all the collateral
    // 3. Stake and tokenize
    // 4: send the collateral to the leverage account
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

  function _onFlashloanClosePosition(
    address who,
    uint256 flashloanAmount,
    uint256[] memory minCollateral
  ) internal {
    LeverageAccount acct = getAccount(who);

    // 1. send the flashloaned arth to the account
    arth.transfer(address(acct), flashloanAmount);

    // 2. use the flashloan'd ARTH to payback the debt and close the loan
    closeLoan(acct, controller, borrowerOperations, flashloanAmount, arth, stakingWrapper);

    // 3. get the collateral and swap back to arth to back the loan
    _unStakeAndWithdrawLP();
    _buyCollateralForARTH(flashloanAmount, minCollateral);

    require(usdc.balanceOf(me) >= minCollateral[0], "not enough usdc");
    require(busd.balanceOf(me) >= minCollateral[1], "not enough busd");

    // 4. payback the loan..
    arth.approve(address(flashLoan), flashloanAmount);
    require(arth.balanceOf(me) >= flashloanAmount, "not enough arth for flashload");
  }

  function _lpAndStake(LeverageAccount acct) internal returns (uint256) {
    // 2. LP all the collateral
    usdc.approve(address(uniswapRouter), usdc.balanceOf(me));
    busd.approve(address(uniswapRouter), busd.balanceOf(me));

    uniswapRouter.addLiquidity(
      address(usdc),
      address(busd),
      usdc.balanceOf(me),
      busd.balanceOf(me),
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

  function _unStakeAndWithdrawLP() internal {
    // 1. unstake and un-tokenize
    uint256 collateralAmount = stakingWrapper.balanceOf(me);
    stakingWrapper.withdraw(collateralAmount);

    // 2. remove from LP
    lp.approve(address(uniswapRouter), lp.balanceOf(me));
    uniswapRouter.removeLiquidity(
      address(usdc),
      address(busd),
      lp.balanceOf(me),
      0, // amountAMin
      0, // amountBMin
      me,
      block.timestamp
    );
  }

  function _sellCollateralForARTH(uint256[] memory borrowedCollateral) internal {
    _buyARTHusdForExact(
      arthUsd,
      busd,
      usdc,
      usdc,
      borrowedCollateral[0], // busd
      borrowedCollateral[1], // usdc amountCIn, amountOutMin, to);
      0, // usdt
      0
    );
  }

  function _buyCollateralForARTH(uint256 amountToSell, uint256[] memory minCollateral) internal {
    _sellARTHusdForExact(
      arth,
      arthUsd,
      amountToSell,
      minCollateral[0], // busd
      minCollateral[1], // usdc
      0 // usdt
    );
  }

  function estimateAmountToFlashloanBuy(uint256[] memory borrowedCollateral)
    public
    view
    returns (uint256)
  {
    return
      estimateARTHusdtoBuy(
        address(busd),
        address(usdc),
        borrowedCollateral[0],
        borrowedCollateral[1]
      );
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
    if (usdc.balanceOf(me) > 0) usdc.transfer(to, usdc.balanceOf(me));
    if (busd.balanceOf(me) > 0) busd.transfer(to, busd.balanceOf(me));
    if (rewardToken.balanceOf(me) > 0) rewardToken.transfer(to, rewardToken.balanceOf(me));
  }
}
