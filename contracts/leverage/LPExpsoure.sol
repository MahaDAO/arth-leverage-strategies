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
  address public controller;

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
  uint256 private MAX_UINT256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

  constructor(
    address _flashloan,
    address _arth,
    address _controller,
    address _maha,
    address _dai,
    address _uniswapRouter,
    address _borrowerOperations,
    address _wrapper,
    address _accountRegistry,
    address _troveManager
  ) UniswapV2Helpers(_uniswapRouter) {
    flashLoan = IFlashLoan(_flashloan);

    controller = _controller;

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
    uint256 minExpectedCollateralRatio
  ) external {
    // estimate how much we should flashloan based on how much we want to borrow
    uint256 flashloanAmount = estimateAmountToFlashloanBuy(borrowedCollateral);

    bytes memory flashloanData = abi.encode(
      msg.sender,
      uint256(0), // action = 0 -> open loan
      minExpectedCollateralRatio,
      borrowedCollateral,
      principalCollateral
    );

    flashLoan.flashLoan(address(this), flashloanAmount.mul(103).div(100), flashloanData);
    _flush(msg.sender);
  }

  function closePosition(uint256[] memory minExpectedCollateral) external {
    bytes memory flashloanData = abi.encode(
      msg.sender,
      uint256(1), // action = 0 -> close loan
      uint256(0),
      minExpectedCollateral,
      minExpectedCollateral
    );

    // need to make this MEV resistant
    uint256 flashloanAmount = troveManager.getTroveDebt(address(getAccount(msg.sender)));
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
      uint256 minExpectedCollateralRatio,
      uint256[] memory borrowedCollateral,
      uint256[] memory principalCollateralOrMinCollateral
    ) = abi.decode(data, (address, uint256, uint256, uint256[], uint256[]));

    // open or close the loan position
    if (action == 0) {
      _onFlashloanOpenPosition(
        who,
        flashloanAmount,
        borrowedCollateral,
        principalCollateralOrMinCollateral,
        minExpectedCollateralRatio
      );
    } else _onFlashloanClosePosition(who, flashloanAmount, principalCollateralOrMinCollateral);

    return keccak256("FlashMinter.onFlashLoan");
  }

  function _onFlashloanOpenPosition(
    address who,
    uint256 flashloanAmount,
    uint256[] memory borrowedCollateral,
    uint256[] memory principalCollateral,
    uint256 minExpectedCollateralRatio
  ) internal {
    // take the principal
    maha.transferFrom(msg.sender, address(this), principalCollateral[0]);
    dai.transferFrom(msg.sender, address(this), principalCollateral[1]);

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
      MAX_UINT256, // maxBorrowingFee, // borrowing fee
      flashloanAmount, // debt + liquidation reserve
      collateralAmount, // collateral
      address(0), // upperHint,
      address(0), // lowerHint,
      address(0), // frontEndTag,
      arth,
      mahaDaiWrapper
    );

    // send the arth back to the flash loan contract to payback the flashloan

    // over here we will have a open loan with collateral and leverage account would've
    // send us back the minted arth
    // 6. payback the loan..

    // 7. check if we met the min leverage conditions
    // require(troveManager.getTroveDebt(address(acct)) >= minExpectedCollateralRation, "min cr not met");
    arth.approve(address(flashLoan), flashloanAmount);
    require(arth.balanceOf(me) >= flashloanAmount, uint2str(arth.balanceOf(me)));
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
    _buyCollateralForARTH(minCollateral);

    require(maha.balanceOf(me) >= minCollateral[0], "not enough maha");
    require(dai.balanceOf(me) >= minCollateral[1], "not enough dai");

    // 4. payback the loan..
    arth.approve(address(flashLoan), flashloanAmount);
  }

  function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
    if (_i == 0) {
      return "0";
    }
    uint256 j = _i;
    uint256 len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint256 k = len;
    while (_i != 0) {
      k = k - 1;
      uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
      bytes1 b1 = bytes1(temp);
      bstr[k] = b1;
      _i /= 10;
    }
    return string(bstr);
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

  function _buyCollateralForARTH(uint256[] memory minCollateral) internal {
    uint256 mahaBalance = maha.balanceOf(me);
    uint256 daiBalance = dai.balanceOf(me);

    uint256 mahaToSell = mahaBalance.sub(minCollateral[0]);
    uint256 daiToSell = daiBalance.sub(minCollateral[1]);

    // 1: sell arth for collateral
    if (mahaToSell > 0) _buyARTHForExact(arth, maha, mahaToSell, 0, me);
    if (daiToSell > 0) _buyARTHForExact(arth, dai, daiToSell, 0, me);
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

  function _unStakeAndWithdrawLP() internal returns (uint256) {
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

  function _flush(address to) internal {
    if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
    if (maha.balanceOf(me) > 0) maha.transfer(to, maha.balanceOf(me));
    if (dai.balanceOf(me) > 0) dai.transfer(to, dai.balanceOf(me));
  }
}
