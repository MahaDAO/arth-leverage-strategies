// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IEllipsisRouter} from "../../../interfaces/IEllipsisRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Wrapper} from "../../../interfaces/IERC20Wrapper.sol";
import {ILeverageStrategy} from "../../../interfaces/ILeverageStrategy.sol";
import {IPriceFeed} from "../../../interfaces/IPriceFeed.sol";
import {ITroveManager} from "../../../interfaces/ITroveManager.sol";
import {IUniswapV2Factory} from "../../../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "../../../interfaces/IUniswapV2Router02.sol";
import {LeverageAccount, LeverageAccountRegistry} from "../../../account/LeverageAccountRegistry.sol";
import {LeverageLibraryBSC} from "../../../helpers/LeverageLibraryBSC.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {TroveHelpers} from "../../../helpers/TroveHelpers.sol";

contract ApeSwapSingleBUSDUSDT is TroveHelpers, ILeverageStrategy {
  using SafeMath for uint256;

  address public borrowerOperations;

  ITroveManager public troveManager;
  IPriceFeed public priceFeed;

  IERC20 public arth;
  IERC20 public busd;
  IERC20 public usdt;
  IERC20 public rewardToken;

  LeverageAccountRegistry public accountRegistry;

  IERC20 public lp;

  IERC20Wrapper public arthUsd;
  IERC20Wrapper public stakingWrapper;

  IEllipsisRouter public ellipsis;
  IUniswapV2Router02 public apeswapRouter;
  IUniswapV2Factory public apeswapFactory;

  address private me;

  constructor(bytes memory data1, bytes memory data2) {
    (
      address _arth,
      address _usdt,
      address _busd,
      address _rewardToken,
      address _ellipsis,
      address _arthUsd,
      address _uniswapRouter // address _borrowerOperations,
    ) = abi.decode(data1, (address, address, address, address, address, address, address));

    (
      address _borrowerOperations,
      address _troveManager,
      address _priceFeed,
      address _stakingWrapper,
      address _accountRegistry
    ) = abi.decode(data2, (address, address, address, address, address));

    ellipsis = IEllipsisRouter(_ellipsis);

    busd = IERC20(_busd);
    arth = IERC20(_arth);
    usdt = IERC20(_usdt);
    rewardToken = IERC20(_rewardToken);
    arthUsd = IERC20Wrapper(_arthUsd);

    me = address(this);

    apeswapRouter = IUniswapV2Router02(_uniswapRouter);
    apeswapFactory = IUniswapV2Factory(apeswapRouter.factory());
    lp = IERC20(apeswapFactory.getPair(_usdt, _busd));

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
    LeverageAccount acct = getAccount(msg.sender);

    // 1: sell arth for collateral
    ellipsis.sellTokenForToken(
      busd,
      1, // busd
      3, // usdt
      principalCollateral[0].sub(finalExposure[0]),
      finalExposure[1],
      me,
      block.timestamp
    );

    // // 2. LP all the collateral
    // usdt.approve(address(apeswapRouter), usdt.balanceOf(me));
    // busd.approve(address(apeswapRouter), busd.balanceOf(me));

    // apeswapRouter.addLiquidity(
    //   address(usdt),
    //   address(busd),
    //   usdt.balanceOf(me),
    //   busd.balanceOf(me),
    //   0,
    //   0,
    //   me,
    //   block.timestamp
    // );

    // // 3. Stake and tokenize
    // uint256 collateralAmount = lp.balanceOf(me);
    // lp.approve(address(stakingWrapper), collateralAmount);
    // stakingWrapper.deposit(collateralAmount);

    // // 4: send the collateral to the leverage account
    // stakingWrapper.transfer(address(acct), collateralAmount);

    // // 5: open loan using the collateral
    // openLoan(
    //   acct,
    //   borrowerOperations,
    //   maxBorrowingFee, // borrowing fee
    //   0, // debt
    //   collateralAmount, // collateral
    //   address(0), // upperHint,
    //   address(0), // lowerHint,
    //   address(0), // frontEndTag,
    //   arth,
    //   stakingWrapper
    // );

    // // 6. check if we met the min leverage conditions
    // require(
    //   LeverageLibraryBSC.getTroveCR(priceFeed, troveManager, address(acct)) >=
    //     minExpectedCollateralRatio,
    //   "min cr not met"
    // );

    _flush(msg.sender);
    emit PositionOpened(msg.sender, address(stakingWrapper), finalExposure, principalCollateral);
  }

  function closePosition(uint256[] memory minExpectedCollateral) external override {
    // todo need to make this MEV resistant
    LeverageAccount acct = getAccount(msg.sender);

    address who = address(acct);
    uint256 flashloanAmount = troveManager.getTroveDebt(who);

    emit PositionClosed(
      msg.sender,
      address(stakingWrapper),
      troveManager.getTroveColl(who),
      flashloanAmount
    );

    // 1. send the flashloaned arth to the account
    arth.transfer(who, flashloanAmount);

    // 2. use the flashloan'd ARTH to payback the debt and close the loan
    closeLoan(acct, address(0), borrowerOperations, flashloanAmount, arth, stakingWrapper);

    // 3. get the collateral and swap back to arth to back the loan
    // 4. unstake and un-tokenize
    uint256 collateralAmount = stakingWrapper.balanceOf(me);
    stakingWrapper.withdraw(collateralAmount);

    // 5. remove from LP
    lp.approve(address(apeswapRouter), lp.balanceOf(me));
    apeswapRouter.removeLiquidity(
      address(usdt),
      address(busd),
      lp.balanceOf(me),
      0, // amountAMin
      0, // amountBMin
      me,
      block.timestamp
    );

    busd.approve(address(ellipsis), busd.balanceOf(me));
    usdt.approve(address(ellipsis), usdt.balanceOf(me));

    ellipsis.buyARTHForExact(
      busd.balanceOf(me).sub(minExpectedCollateral[0]),
      0,
      usdt.balanceOf(me),
      flashloanAmount,
      me,
      block.timestamp
    );

    require(busd.balanceOf(me) >= minExpectedCollateral[0], "not enough busd");
    // require(usdt.balanceOf(me) >= minCollateral[1], "not enough usdt");

    LeverageLibraryBSC.swapExcessARTH(me, msg.sender, 1, ellipsis, arth);
    _flush(msg.sender);
  }

  function rewardsEarned(address who) external view override returns (uint256) {
    return LeverageLibraryBSC.rewardsEarned(accountRegistry, troveManager, stakingWrapper, who);
  }

  function underlyingCollateralFromBalance(uint256 bal)
    external
    view
    override
    returns (uint256[2] memory)
  {
    return LeverageLibraryBSC.underlyingCollateralFromBalance(bal, address(lp));
  }

  function _flush(address to) internal {
    if (arth.balanceOf(me) > 0) {
      arth.approve(address(arthUsd), arth.balanceOf(me));
      arthUsd.deposit(arth.balanceOf(me));
    }
    if (arthUsd.balanceOf(me) > 0) arthUsd.transfer(to, arthUsd.balanceOf(me));
    if (usdt.balanceOf(me) > 0) usdt.transfer(to, usdt.balanceOf(me));
    if (busd.balanceOf(me) > 0) busd.transfer(to, busd.balanceOf(me));
    if (rewardToken.balanceOf(me) > 0) rewardToken.transfer(to, rewardToken.balanceOf(me));
  }
}
