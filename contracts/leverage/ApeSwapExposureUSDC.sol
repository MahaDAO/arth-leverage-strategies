// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IEllipsisRouter} from "../interfaces/IEllipsisRouter.sol";
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
import {LeverageLibraryBSC} from "../helpers/LeverageLibraryBSC.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {TroveLibrary} from "../helpers/TroveLibrary.sol";

contract ApeSwapExposureUSDC is IFlashBorrower, ILeverageStrategy {
  using SafeMath for uint256;

  address public borrowerOperations;

  ITroveManager public troveManager;
  IPriceFeed public priceFeed;

  IERC20 public arth;
  IERC20 public busd;
  IERC20 public usdc;
  IERC20 public rewardToken;

  IFlashLoan public flashLoan;
  LeverageAccountRegistry public accountRegistry;

  IERC20 public lp;

  IERC20Wrapper public arthUsd;
  IERC20Wrapper public stakingWrapper;

  IEllipsisRouter public ellipsis;
  IUniswapV2Router02 public apeswapRouter;
  IUniswapV2Factory public apeswapFactory;

  address private me;

  constructor(
    address _flashloan,
    address _arth,
    address _usdc,
    address _busd,
    address _rewardToken,
    address _ellipsisRouter,
    address _arthUsd,
    address _uniswapRouter
  ) {
    ellipsis = IEllipsisRouter(_ellipsisRouter);

    busd = IERC20(_busd);
    arth = IERC20(_arth);
    usdc = IERC20(_usdc);
    rewardToken = IERC20(_rewardToken);
    flashLoan = IFlashLoan(_flashloan);
    arthUsd = IERC20Wrapper(_arthUsd);

    me = address(this);

    apeswapRouter = IUniswapV2Router02(_uniswapRouter);
    apeswapFactory = IUniswapV2Factory(apeswapRouter.factory());
    lp = IERC20(apeswapFactory.getPair(_usdc, _busd));
  }

  function init(
    address _borrowerOperations,
    address _troveManager,
    address _priceFeed,
    address _stakingWrapper,
    address _accountRegistry
  ) public {
    require(borrowerOperations == address(0), "already initialized");
    borrowerOperations = _borrowerOperations;
    troveManager = ITroveManager(_troveManager);
    priceFeed = IPriceFeed(_priceFeed);
    stakingWrapper = IERC20Wrapper(_stakingWrapper);
    accountRegistry = LeverageAccountRegistry(_accountRegistry);
  }

  function getAccount(address who) public view returns (LeverageAccount) {
    return accountRegistry.accounts(who);
  }

  function openPosition(
    uint256[] memory finalExposure,
    uint256[] memory principalCollateral,
    uint256 minExpectedCollateralRatio,
    uint256 maxBorrowingFee
  ) external override {
    // take the principal
    busd.transferFrom(msg.sender, address(this), principalCollateral[0]);

    // todo swap excess

    // estimate how much we should flashloan based on how much we want to borrow
    uint256 flashloanAmount = ellipsis
      .estimateARTHtoBuy(
        finalExposure[0].sub(principalCollateral[0]),
        finalExposure[1].sub(principalCollateral[0]),
        0
      )
      .mul(101)
      .div(100);

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

    emit PositionOpened(msg.sender, address(stakingWrapper), finalExposure, principalCollateral);
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

    // todo need to make this MEV resistant
    address who = address(getAccount(msg.sender));
    uint256 flashloanAmount = troveManager.getTroveDebt(who);
    flashLoan.flashLoan(address(this), flashloanAmount, flashloanData);

    emit PositionClosed(
      msg.sender,
      address(stakingWrapper),
      troveManager.getTroveColl(who),
      flashloanAmount
    );

    // any pending ARTH; swap for BUSD and send it back to the user
    LeverageLibraryBSC.swapExcessARTH(me, msg.sender, ellipsis, arth);

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
      uint256[] memory finalExposure,
      uint256[] memory minCollateralOrPrincipalCollateral
    ) = abi.decode(data, (address, uint256, uint256, uint256, uint256[], uint256[]));

    // open or close the loan position
    if (action == 0) {
      _onFlashloanOpenPosition(
        who,
        flashloanAmount,
        finalExposure,
        minCollateralOrPrincipalCollateral,
        minExpectedCollateralRatio,
        maxBorrowingFee
      );
    } else _onFlashloanClosePosition(who, flashloanAmount, minCollateralOrPrincipalCollateral);

    return keccak256("FlashMinter.onFlashLoan");
  }

  function _onFlashloanOpenPosition(
    address who,
    uint256 flashloanAmount,
    uint256[] memory finalExposure,
    uint256[] memory principalCollateral,
    uint256 minExpectedCollateralRatio,
    uint256 maxBorrowingFee
  ) internal {
    LeverageAccount acct = getAccount(who);

    // 1: sell arth for collateral
    arth.approve(address(ellipsis), flashloanAmount);
    ellipsis.sellARTHForExact(
      flashloanAmount,
      finalExposure[0].sub(principalCollateral[0]), // amountBUSDOut,
      finalExposure[1], // amountUSDCOut,
      0, // amountUSDTOut,
      me,
      block.timestamp
    );

    // 2. LP all the collateral
    usdc.approve(address(apeswapRouter), usdc.balanceOf(me));
    busd.approve(address(apeswapRouter), busd.balanceOf(me));

    apeswapRouter.addLiquidity(
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
    stakingWrapper.transfer(address(acct), collateralAmount);

    // 5: open loan using the collateral
    uint256 debt = flashloanAmount.sub(arth.balanceOf(me));
    TroveLibrary.openLoan(
      acct,
      borrowerOperations,
      maxBorrowingFee, // borrowing fee
      debt, // debt
      collateralAmount, // collateral
      address(0), // upperHint,
      address(0), // lowerHint,
      address(0), // frontEndTag,
      arth,
      stakingWrapper
    );

    // 6. check if we met the min leverage conditions
    require(
      LeverageLibraryBSC.getTroveCR(priceFeed, troveManager, who) >= minExpectedCollateralRatio,
      "min cr not met"
    );

    // 7. payback the loan..
    arth.approve(address(flashLoan), flashloanAmount);
    require(arth.balanceOf(me) >= flashloanAmount, "not enough arth for flashloan");
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
    TroveLibrary.closeLoan(
      acct,
      address(0),
      borrowerOperations,
      flashloanAmount,
      arth,
      stakingWrapper
    );

    // 3. get the collateral and swap back to arth to back the loan
    // 4. unstake and un-tokenize
    uint256 collateralAmount = stakingWrapper.balanceOf(me);
    stakingWrapper.withdraw(collateralAmount);

    // 5. remove from LP
    lp.approve(address(apeswapRouter), lp.balanceOf(me));
    apeswapRouter.removeLiquidity(
      address(usdc),
      address(busd),
      lp.balanceOf(me),
      0, // amountAMin
      0, // amountBMin
      me,
      block.timestamp
    );

    busd.approve(address(ellipsis), busd.balanceOf(me));
    usdc.approve(address(ellipsis), usdc.balanceOf(me));

    ellipsis.buyARTHForExact(
      busd.balanceOf(me).sub(minCollateral[0]),
      usdc.balanceOf(me),
      0,
      flashloanAmount,
      me,
      block.timestamp
    );

    require(busd.balanceOf(me) >= minCollateral[0], "not enough busd");
    // require(usdc.balanceOf(me) >= minCollateral[1], "not enough usdc");

    // 4. payback the loan..
    arth.approve(address(flashLoan), flashloanAmount);
    require(arth.balanceOf(me) >= flashloanAmount, "not enough for flashload");
  }

  function rewardsEarned(address who) external view override returns (uint256) {
    return LeverageLibraryBSC.rewardsEarned(accountRegistry, troveManager, stakingWrapper, who);
  }

  function _flush(address to) internal {
    if (arth.balanceOf(me) > 0) {
      arth.approve(address(arthUsd), arth.balanceOf(me));
      arthUsd.deposit(arth.balanceOf(me));
    }
    if (arthUsd.balanceOf(me) > 0) arthUsd.transfer(to, arthUsd.balanceOf(me));
    if (usdc.balanceOf(me) > 0) usdc.transfer(to, usdc.balanceOf(me));
    if (busd.balanceOf(me) > 0) busd.transfer(to, busd.balanceOf(me));
    if (rewardToken.balanceOf(me) > 0) rewardToken.transfer(to, rewardToken.balanceOf(me));
  }
}
