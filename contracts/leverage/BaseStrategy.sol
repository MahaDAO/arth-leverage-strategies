// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashBorrower} from "../interfaces/IFlashBorrower.sol";
import {IFlashLoan} from "../interfaces/IFlashLoan.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {ILeverageStrategy} from "../interfaces/ILeverageStrategy.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {LeverageAccount, LeverageAccountRegistry} from "../account/LeverageAccountRegistry.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {TroveHelpers} from "../helpers/TroveHelpers.sol";

contract BaseStrategy is IFlashBorrower, TroveHelpers {
  using SafeMath for uint256;

  address public borrowerOperations;
  address public controller;
  ITroveManager public troveManager;

  IERC20 public immutable arth;
  IERC20 public immutable maha;
  IERC20 public immutable dai;
  IFlashLoan public flashLoan;
  LeverageAccountRegistry public accountRegistry;
  IUniswapV2Router02 public immutable uniswapRouter;

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
    address _controller,
    address _accountRegistry,
    address _troveManager
  ) {
    flashLoan = IFlashLoan(_flashloan);

    arth = IERC20(_arth);
    maha = IERC20(_maha);
    dai = IERC20(_dai);
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
    uint256 flashloanAmount = estimateARTHtoSell(address(maha), borrowedCollateral[0]) +
      estimateARTHtoSell(address(dai), borrowedCollateral[1]);

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

    uint256 flashloanAmount = troveManager.getTroveDebt(address(getAccount(msg.sender)));
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
      uint256[] memory principalCollateral,
      uint256[] memory minExposure,
      address upperHint,
      address lowerHint,
      address frontEndTag
    ) = abi.decode(
        data,
        (address, uint256, uint256, uint256[], uint256[], address, address, address)
      );

    // open or close the loan position
    if (action == 0) {
      _onFlashloanOpenPosition(
        who,
        flashloanAmount,
        maxBorrowingFee,
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
    uint256[] memory principalCollateral,
    uint256[] memory minExposure,
    address upperHint,
    address lowerHint,
    address frontEndTag
  ) internal {
    LeverageAccount acct = getAccount(who);

    // 1: sell arth for collateral
    _sellCollateralForARTH(acct, flashloanAmount, principalCollateral, minExposure);

    // 2. LP all the collateral
    // 3. Stake and tokenize
    // 4: send the collateral to the leverage account
    uint256 collateralAmount = _lpAndStake(acct);

    // 5: open loan using the collateral
    openLoan(
      acct,
      borrowerOperations,
      maxBorrowingFee, // borrowing fee
      flashloanAmount.add(10 * 1e18), // debt + liquidation reserve
      collateralAmount, // collateral
      upperHint,
      lowerHint,
      frontEndTag,
      arth,
      mahaDaiWrapper
    );

    // over here we will have a open loan with collateral and leverage account would've
    // send us back the minted arth
    // 6. payback the loan..

    // 7. check if we met the min leverage conditions
    // require(troveManager.getTroveDebt(address(acct)) >= minExposure, "min exposure not met");
  }

  function _sellCollateralForARTH(
    LeverageAccount acct,
    uint256 flashloanAmount,
    uint256[] memory principalCollateral,
    uint256[] memory minExposure
  ) internal {
    // 1: sell arth for collateral
    uint256 mahaCollateralAmount = maha.balanceOf(address(acct)).add(principalCollateral[0]);
    if (mahaCollateralAmount < minExposure[0]) {
      uint256 mahaNeeded = minExposure[0].sub(mahaCollateralAmount);
      _sellARTHForExact(maha, mahaNeeded, flashloanAmount, address(acct));
    }

    uint256 daiCollateralAmount = maha.balanceOf(address(acct)).add(principalCollateral[0]);
    if (daiCollateralAmount < minExposure[0]) {
      uint256 daiNeeded = minExposure[0].sub(daiCollateralAmount);
      _sellARTHForExact(dai, daiNeeded, flashloanAmount, address(acct));
    }
  }

  function _lpAndStake(LeverageAccount acct) internal returns (uint256) {
    // 2. LP all the collateral
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
    LeverageAccount acct = getAccount(who);
    // // 1. send the flashloaned arth to the account
    arth.transfer(address(acct), flashloanAmount);
    // // 2. use the flashloan'd ARTH to payback the debt and close the loan
    // closeLoan(acct, controller, borrowerOperations, flashloanAmount, arth, wmatic);
    // // 3. get the collateral and swap back to arth to back the loan
    // uint256 totalCollateralAmount = wmatic.balanceOf(address(this));
    // uint256 arthBal = arth.balanceOf(address(this));
    // uint256 pendingArth = flashloanAmount.sub(arthBal);
    // _buyExactARTH(pendingArth, totalCollateralAmount, address(this));
    // // 4. payback the loan..
  }

  function _sellARTHForExact(
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

  function estimateARTHtoSell(address tokenB, uint256 maticNeeded)
    public
    view
    returns (uint256 arthToSell)
  {
    if (maticNeeded == 0) return 0;

    address[] memory path = new address[](2);
    path[0] = address(arth);
    path[1] = address(tokenB);

    uint256[] memory amountsOut = uniswapRouter.getAmountsIn(maticNeeded, path);
    arthToSell = amountsOut[0];
  }

  function estimateARTHtoBuy(address tokenB, uint256 arthNeeded)
    public
    view
    returns (uint256 maticToSell)
  {
    if (arthNeeded == 0) return 0;

    address[] memory path = new address[](2);
    path[0] = address(tokenB);
    path[1] = address(arth);

    uint256[] memory amountsOut = uniswapRouter.getAmountsIn(arthNeeded, path);
    maticToSell = amountsOut[0];
  }

  function _flush(address to) internal {
    if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
    if (maha.balanceOf(me) > 0) maha.transfer(to, maha.balanceOf(me));
    if (dai.balanceOf(me) > 0) dai.transfer(to, dai.balanceOf(me));
  }
}
