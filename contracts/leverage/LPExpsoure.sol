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
import {UniswapV2Helpers} from "../helpers/UniswapV2Helpers.sol";

contract LPExpsoure is IFlashBorrower, ILeverageStrategy, TroveHelpers, UniswapV2Helpers {
  using SafeMath for uint256;

  address public borrowerOperations;
  address public controller;

  ITroveManager public troveManager;
  IPriceFeed public priceFeed;

  IERC20 public arth;
  IERC20 public maha;
  IERC20 public dai;
  IERC20 public dQuick;

  IFlashLoan public flashLoan;
  LeverageAccountRegistry public accountRegistry;

  IERC20 public mahaDai;

  IERC20Wrapper public mahaDaiWrapper;

  address private me;

  constructor(
    address _flashloan,
    address _controller,
    address _maha,
    address _dai,
    address _dQuick,
    address _uniswapRouter,
    address _borrowerOperations,
    address _wrapper,
    address _accountRegistry,
    address _troveManager,
    address _priceFeed
  ) UniswapV2Helpers(_uniswapRouter) {
    accountRegistry = LeverageAccountRegistry(_accountRegistry);
    borrowerOperations = _borrowerOperations;
    controller = _controller;
    dai = IERC20(_dai);
    flashLoan = IFlashLoan(_flashloan);
    maha = IERC20(_maha);
    dQuick = IERC20(_dQuick);

    mahaDaiWrapper = IERC20Wrapper(_wrapper);
    priceFeed = IPriceFeed(_priceFeed);
    troveManager = ITroveManager(_troveManager);
    uniswapRouter = IUniswapV2Router02(_uniswapRouter);

    arth = troveManager.lusdToken();
    uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());
    mahaDai = IERC20(uniswapFactory.getPair(_dai, _maha));

    me = address(this);
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
    maha.transferFrom(msg.sender, address(this), principalCollateral[0]);
    dai.transferFrom(msg.sender, address(this), principalCollateral[1]);

    // estimate how much we should flashloan based on how much we want to borrow
    uint256 flashloanAmount = estimateAmountToFlashloanBuy(borrowedCollateral);

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
      mahaDaiWrapper
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
    closeLoan(acct, controller, borrowerOperations, flashloanAmount, arth, mahaDaiWrapper);

    // 3. get the collateral and swap back to arth to back the loan
    _unStakeAndWithdrawLP();
    _buyCollateralForARTH(flashloanAmount, minCollateral);

    require(maha.balanceOf(me) >= minCollateral[0], "not enough maha");
    require(dai.balanceOf(me) >= minCollateral[1], "not enough dai");

    // 4. payback the loan..
    arth.approve(address(flashLoan), flashloanAmount);
    require(arth.balanceOf(me) >= flashloanAmount, "not enough arth for flashload");
  }

  function _sellCollateralForARTH(uint256[] memory borrowedCollateral) internal {
    // 1: sell arth for collateral
    if (borrowedCollateral[0] > 0) {
      uint256 sell0 = estimateARTHtoSell(arth, maha, borrowedCollateral[0]);
      _sellARTHForExact(arth, maha, borrowedCollateral[0], sell0, me);
    }

    if (borrowedCollateral[1] > 0) {
      uint256 sell1 = estimateARTHtoSell(arth, dai, borrowedCollateral[1]);
      _sellARTHForExact(arth, dai, borrowedCollateral[1], sell1, me);
    }
  }

  function _buyCollateralForARTH(uint256 minARTH, uint256[] memory minCollateral) internal {
    uint256 mahaBalance = maha.balanceOf(me);
    uint256 daiBalance = dai.balanceOf(me);

    uint256 mahaToSell = mahaBalance.sub(minCollateral[0]);
    uint256 daiToSell = daiBalance.sub(minCollateral[1]);

    // 1: sell arth for collateral; atm we do 50-50
    if (mahaToSell > 0) _buyExactARTH(arth, maha, minARTH.div(2), mahaToSell, me);
    if (daiToSell > 0) _buyExactARTH(arth, dai, minARTH.div(2), daiToSell, me);
  }

  function _lpAndStake(LeverageAccount acct) internal returns (uint256) {
    // 2. LP all the collateral
    maha.approve(address(uniswapRouter), maha.balanceOf(me));
    dai.approve(address(uniswapRouter), dai.balanceOf(me));

    uniswapRouter.addLiquidity(
      address(maha),
      address(dai),
      maha.balanceOf(me),
      dai.balanceOf(me),
      0,
      0,
      me,
      block.timestamp
    );

    // 3. Stake and tokenize
    uint256 collateralAmount = mahaDai.balanceOf(me);
    mahaDai.approve(address(mahaDaiWrapper), collateralAmount);
    mahaDaiWrapper.deposit(collateralAmount);

    // 4: send the collateral to the leverage account
    if (collateralAmount > 0) mahaDaiWrapper.transfer(address(acct), collateralAmount);
    return collateralAmount;
  }

  function _unStakeAndWithdrawLP() internal {
    // 1. unstake and un-tokenize
    uint256 collateralAmount = mahaDaiWrapper.balanceOf(me);
    mahaDaiWrapper.withdraw(collateralAmount);

    // 2. remove from LP
    mahaDai.approve(address(uniswapRouter), mahaDai.balanceOf(me));
    uniswapRouter.removeLiquidity(
      address(maha),
      address(dai),
      mahaDai.balanceOf(me),
      0, // amountAMin
      0, // amountBMin
      me,
      block.timestamp
    );
  }

  function estimateAmountToFlashloanBuy(uint256[] memory borrowedCollateral)
    public
    view
    returns (uint256)
  {
    return
      estimateARTHtoSell(arth, maha, borrowedCollateral[0]) +
      estimateARTHtoSell(arth, dai, borrowedCollateral[1]);
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
    if (maha.balanceOf(me) > 0) maha.transfer(to, maha.balanceOf(me));
    if (dai.balanceOf(me) > 0) dai.transfer(to, dai.balanceOf(me));
    if (dQuick.balanceOf(me) > 0) dQuick.transfer(to, dQuick.balanceOf(me));
  }
}
