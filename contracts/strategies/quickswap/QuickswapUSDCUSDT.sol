// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IStableSwapRouter} from "../../interfaces/IStableSwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Wrapper} from "../../interfaces/IERC20Wrapper.sol";
import {IFlashBorrower} from "../../interfaces/IFlashBorrower.sol";
import {IFlashLoan} from "../../interfaces/IFlashLoan.sol";
import {ILeverageStrategy} from "../../interfaces/ILeverageStrategy.sol";
import {IPriceFeed} from "../../interfaces/IPriceFeed.sol";
import {ITroveManager} from "../../interfaces/ITroveManager.sol";
import {IUniswapV2Factory} from "../../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "../../interfaces/IUniswapV2Router02.sol";
import {LeverageAccount, LeverageAccountRegistry} from "../../account/LeverageAccountRegistry.sol";
import {LeverageLibrary} from "../../helpers/LeverageLibrary.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {TroveLibrary} from "../../helpers/TroveLibrary.sol";

contract QuickswapUSDCUSDT is IFlashBorrower, ILeverageStrategy {
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

  IERC20 public lp;

  IERC20Wrapper public arthUsd;
  IERC20Wrapper public stakingWrapper;

  IStableSwapRouter public curve;
  IUniswapV2Router02 public quickswapRouter;
  IUniswapV2Factory public apeswapFactory;

  address private me;

  constructor(bytes memory data1, bytes memory data2) {
    (
      address _flashloan,
      address _controller,
      address _arth,
      address _usdc,
      address _usdt,
      address _rewardToken,
      address _curve,
      address _arthUsd,
      address _uniswapRouter // address _borrowerOperations,
    ) = abi.decode(
        data1,
        (address, address, address, address, address, address, address, address, address)
      );

    (
      address _borrowerOperations,
      address _troveManager,
      address _priceFeed,
      address _stakingWrapper,
      address _accountRegistry
    ) = abi.decode(data2, (address, address, address, address, address));

    controller = _controller;
    curve = IStableSwapRouter(_curve);

    usdt = IERC20(_usdt);
    arth = IERC20(_arth);
    usdc = IERC20(_usdc);
    rewardToken = IERC20(_rewardToken);
    flashLoan = IFlashLoan(_flashloan);
    arthUsd = IERC20Wrapper(_arthUsd);

    me = address(this);

    quickswapRouter = IUniswapV2Router02(_uniswapRouter);
    apeswapFactory = IUniswapV2Factory(quickswapRouter.factory());
    lp = IERC20(apeswapFactory.getPair(_usdc, _usdt));

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
    uint256[2] memory finalExposure,
    uint256[2] memory principalCollateral,
    uint256 minExpectedCollateralRatio,
    uint256 maxBorrowingFee
  ) external override {
    // take the principal
    usdc.transferFrom(msg.sender, address(this), principalCollateral[0]);

    // todo swap excess

    // estimate how much we should flashloan based on how much we want to borrow
    uint256 flashloanAmount = curve
      .estimateARTHtoBuy(finalExposure[0].sub(principalCollateral[0]), finalExposure[1], 0)
      .mul(102)
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

  function closePosition(uint256[2] memory minExpectedCollateral) external override {
    bytes memory flashloanData = abi.encode(
      msg.sender,
      uint256(1), // action = 1 -> close loan
      uint256(0),
      uint256(0),
      minExpectedCollateral,
      minExpectedCollateral
    );

    // todo need to make this MEV resistant
    address who = address(getAccount(msg.sender));
    uint256 flashloanAmount = troveManager.getTroveDebt(who);

    emit PositionClosed(
      msg.sender,
      address(stakingWrapper),
      troveManager.getTroveColl(who),
      flashloanAmount
    );

    flashLoan.flashLoan(address(this), flashloanAmount, flashloanData);

    LeverageLibrary.swapExcessARTH(me, msg.sender, 1, curve, arth);
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
      uint256[2] memory finalExposure,
      uint256[2] memory minCollateralOrPrincipalCollateral
    ) = abi.decode(data, (address, uint256, uint256, uint256, uint256[2], uint256[2]));

    // open or close the loan position
    if (action == 0) {
      _onFlashloanOpenPosition(
        who,
        flashloanAmount.add(fee),
        finalExposure,
        minCollateralOrPrincipalCollateral,
        minExpectedCollateralRatio,
        maxBorrowingFee
      );
    } else
      _onFlashloanClosePosition(who, flashloanAmount.add(fee), minCollateralOrPrincipalCollateral);

    return keccak256("FlashMinter.onFlashLoan");
  }

  function _onFlashloanOpenPosition(
    address who,
    uint256 flashloanAmount,
    uint256[2] memory finalExposure,
    uint256[2] memory principalCollateral,
    uint256 minExpectedCollateralRatio,
    uint256 maxBorrowingFee
  ) internal {
    LeverageAccount acct = getAccount(who);

    // 1: sell arth for collateral
    arth.approve(address(curve), flashloanAmount);
    curve.sellARTHForExact(
      flashloanAmount,
      0, // amountDAIOut,
      finalExposure[0].sub(principalCollateral[0]), // amountusdCOut,
      finalExposure[1], // amountUSDTOut,
      me,
      block.timestamp
    );

    // 2. LP all the collateral
    usdc.approve(address(quickswapRouter), usdc.balanceOf(me));
    usdt.approve(address(quickswapRouter), usdt.balanceOf(me));
    quickswapRouter.addLiquidity(
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
      LeverageLibrary.getTroveCR(priceFeed, troveManager, address(acct)) >=
        minExpectedCollateralRatio,
      "min cr not met"
    );

    // 7. payback the loan..
    arth.approve(address(flashLoan), flashloanAmount);
    require(arth.balanceOf(me) >= flashloanAmount, "not enough arth for flashloan");
  }

  function _onFlashloanClosePosition(
    address who,
    uint256 flashloanAmount,
    uint256[2] memory minCollateral
  ) internal {
    LeverageAccount acct = getAccount(who);

    // 1. send the flashloaned arth to the account
    arth.transfer(address(acct), flashloanAmount);

    // 2. use the flashloan'd ARTH to payback the debt and close the loan
    TroveLibrary.closeLoan(
      acct,
      controller,
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
    lp.approve(address(quickswapRouter), lp.balanceOf(me));
    quickswapRouter.removeLiquidity(
      address(usdc),
      address(usdt),
      lp.balanceOf(me),
      0, // amountAMin
      0, // amountBMin
      me,
      block.timestamp
    );

    usdt.approve(address(curve), usdt.balanceOf(me));
    usdc.approve(address(curve), usdc.balanceOf(me));

    curve.buyARTHForExact(
      0,
      usdc.balanceOf(me),
      usdt.balanceOf(me).sub(minCollateral[0]),
      flashloanAmount,
      me,
      block.timestamp
    );

    require(usdt.balanceOf(me) >= minCollateral[0], "not enough usdt");
    // require(usdc.balanceOf(me) >= minCollateral[1], "not enough usdc");

    // 4. payback the loan..
    arth.approve(address(flashLoan), flashloanAmount);
    require(arth.balanceOf(me) >= flashloanAmount, "not enough for flashload");
  }

  function rewardsEarned(address who) external view override returns (uint256) {
    return LeverageLibrary.rewardsEarned(accountRegistry, troveManager, stakingWrapper, who);
  }

  function underlyingCollateralFromBalance(uint256 bal)
    external
    view
    override
    returns (uint256[2] memory)
  {
    return LeverageLibrary.underlyingCollateralFromBalance(bal, address(lp));
  }

  function _flush(address to) internal {
    if (arth.balanceOf(me) > 0) {
      arth.approve(address(arthUsd), arth.balanceOf(me));
      arthUsd.deposit(arth.balanceOf(me));
    }
    if (arthUsd.balanceOf(me) > 0) arthUsd.transfer(to, arthUsd.balanceOf(me));
    if (usdc.balanceOf(me) > 0) usdc.transfer(to, usdc.balanceOf(me));
    if (usdt.balanceOf(me) > 0) usdt.transfer(to, usdt.balanceOf(me));
    if (rewardToken.balanceOf(me) > 0) rewardToken.transfer(to, rewardToken.balanceOf(me));
  }
}
