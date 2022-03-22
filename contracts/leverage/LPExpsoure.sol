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
import {UniswapV2Helpers} from "../helpers/UniswapV2Helpers.sol";

contract LPExpsoure is IFlashBorrower, TroveHelpers, UniswapV2Helpers {
  using SafeMath for uint256;

  address public borrowerOperations;
  ITroveManager public troveManager;

  IERC20 public immutable arth;
  IERC20 public immutable maha;
  IERC20 public immutable dai;
  IFlashLoan public flashLoan;
  LeverageAccountRegistry public accountRegistry;

  IERC20 public arthMaha;
  IERC20 public arthDai;
  IERC20 public mahaDai;

  IERC20Wrapper public mahaDaiWrapper;

  address private me;

  constructor(
    address _flashloan,
    address _arth,
    address _maha,
    address _dai,
    address _uniswapRouter,
    address _borrowerOperations,
    address _wrapper,
    address _accountRegistry,
    address _troveManager
  ) UniswapV2Helpers(_uniswapRouter) {
    flashLoan = IFlashLoan(_flashloan);

    arth = IERC20(_arth);
    maha = IERC20(_maha);
    dai = IERC20(_dai);
    uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    borrowerOperations = _borrowerOperations;
    troveManager = ITroveManager(_troveManager);
    accountRegistry = LeverageAccountRegistry(_accountRegistry);

    uniswapFactory = IUniswapV2Factory(uniswapRouter.factory());

    arthDai = IERC20(uniswapFactory.getPair(_arth, _dai));
    arthMaha = IERC20(uniswapFactory.getPair(_arth, _maha));
    mahaDai = IERC20(uniswapFactory.getPair(_dai, _maha));

    mahaDaiWrapper = IERC20Wrapper(_wrapper);

    me = address(this);
  }

  function getAccount(address who) public view returns (LeverageAccount) {
    return accountRegistry.accounts(who);
  }

  function openPosition(
    uint256[] memory borrowedCollateral,
    uint256[] memory principalCollateral,
    uint256[] memory minExposure,
    uint256 maxBorrowingFee,
    address upperHint,
    address lowerHint,
    address frontEndTag
  ) external {
    // take the principal
    maha.transferFrom(msg.sender, address(this), principalCollateral[0]);
    dai.transferFrom(msg.sender, address(this), principalCollateral[1]);

    // estimate how much we should flashloan based on how much we want to borrow
    uint256 flashloanAmount = estimateAmountToFlashloanBuy(borrowedCollateral);

    bytes memory flashloanData = abi.encode(
      msg.sender,
      uint256(0), // action = 0 -> open loan
      maxBorrowingFee,
      borrowedCollateral,
      principalCollateral,
      minExposure,
      upperHint,
      lowerHint,
      frontEndTag
    );

    flashLoan.flashLoan(address(this), flashloanAmount.mul(103).div(100), flashloanData);
    _flush(msg.sender);
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
    uint256 flashloanAmount = troveManager.getTroveDebt(msg.sender);
    arth.approve(address(flashLoan), flashloanAmount);
    flashLoan.flashLoan(address(this), flashloanAmount, flashloanData);
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
      uint256 maxBorrowingFee,
      uint256[] memory borrowedCollateral,
      uint256[] memory principalCollateral,
      uint256[] memory minExposure,
      address upperHint,
      address lowerHint,
      address frontEndTag
    ) = abi.decode(
        data,
        (address, uint256, uint256, uint256[], uint256[], uint256[], address, address, address)
      );

    // open or close the loan position
    if (action == 0) {
      _onFlashloanOpenPosition(
        who,
        flashloanAmount,
        maxBorrowingFee,
        borrowedCollateral,
        principalCollateral,
        minExposure,
        upperHint,
        lowerHint,
        frontEndTag
      );
    } else _onFlashloanClosePosition(who, flashloanAmount);

    return keccak256("FlashMinter.onFlashLoan");
  }

  function _onFlashloanOpenPosition(
    address who,
    uint256 flashloanAmount,
    uint256 maxBorrowingFee,
    uint256[] memory borrowedCollateral,
    uint256[] memory principalCollateral,
    uint256[] memory minExposure,
    address upperHint,
    address lowerHint,
    address frontEndTag
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
      upperHint,
      lowerHint,
      frontEndTag,
      arth,
      mahaDaiWrapper
    );

    // send the arth back to the flash loan contract to payback the flashloan

    // over here we will have a open loan with collateral and leverage account would've
    // send us back the minted arth
    // 6. payback the loan..

    // 7. check if we met the min leverage conditions
    // require(troveManager.getTroveDebt(address(acct)) >= minExposure, "min exposure not met");
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

  function _onFlashloanClosePosition(address who, uint256 flashloanAmount) internal {
    // LeverageAccount acct = getAccount(who);
    // // // 1. send the flashloaned arth to the account
    // arth.transfer(address(acct), flashloanAmount);
    // // 2. use the flashloan'd ARTH to payback the debt and close the loan
    // closeLoan(acct, controller, borrowerOperations, flashloanAmount, arth, wmatic);
    // // 3. get the collateral and swap back to arth to back the loan
    // uint256 totalCollateralAmount = wmatic.balanceOf(address(this));
    // uint256 arthBal = arth.balanceOf(address(this));
    // uint256 pendingArth = flashloanAmount.sub(arthBal);
    // _buyExactARTH(pendingArth, totalCollateralAmount, address(this));
    // // 4. payback the loan..
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

  function _flush(address to) internal {
    if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
    if (maha.balanceOf(me) > 0) maha.transfer(to, maha.balanceOf(me));
    if (dai.balanceOf(me) > 0) dai.transfer(to, dai.balanceOf(me));
  }
}
