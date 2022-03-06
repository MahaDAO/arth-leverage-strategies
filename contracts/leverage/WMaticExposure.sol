// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IFlashBorrower} from "../interfaces/IFlashBorrower.sol";
import {IFlashLoan} from "../interfaces/IFlashLoan.sol";
import {ILeverageStrategy} from "../interfaces/ILeverageStrategy.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {TroveHelpers} from "../helpers/TroveHelpers.sol";
import {DSProxyRegistry} from "../proxy/DSProxyRegistry.sol";
import {DSProxy} from "../proxy/DSProxy.sol";

contract WMaticExposure is ILeverageStrategy, IFlashBorrower, TroveHelpers {
  using SafeMath for uint256;

  event OpenPosition(uint256 amount, address who);

  address public borrowerOperations;
  IERC20 public immutable arth;
  IERC20 public immutable usdc;
  IERC20 public immutable wmatic;
  IFlashLoan public flashLoan;
  DSProxyRegistry public proxyRegistry;
  IUniswapV2Router02 public immutable uniswapRouter;

  event Where(address who, uint256 line);

  constructor(
    address _flashloan,
    address _arth,
    address _wmatic,
    address _usdc,
    address _uniswapRouter,
    address _borrowerOperations,
    address _proxyRegistry
  ) {
    flashLoan = IFlashLoan(_flashloan);

    arth = IERC20(_arth);
    usdc = IERC20(_usdc);
    wmatic = IERC20(_wmatic);
    uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    borrowerOperations = _borrowerOperations;
    proxyRegistry = DSProxyRegistry(_proxyRegistry);
  }

  // function getProxy () view  return(address) {

  // }

  function openPosition(
    uint256 borrowAmount,
    uint256 minExposure,
    bytes memory data
  ) external override {
    (
      uint256 maxFee,
      uint256 debt,
      uint256 collateralAmount,
      address upperHint,
      address lowerHint,
      address frontEndTag
    ) = abi.decode(data, (uint256, uint256, uint256, address, address, address));

    bytes memory flashloanData = abi.encode(
      msg.sender,
      uint256(0), // action = 0 -> open loan
      maxFee,
      debt,
      collateralAmount,
      upperHint,
      lowerHint,
      frontEndTag
    );

    flashLoan.flashLoan(address(this), borrowAmount, flashloanData);
  }

  function closePosition(uint256 borrowAmount) external override {
    // bytes memory flashloanData = abi.encode(
    //   msg.sender,
    //   uint256(1),
    //   uint256(0),
    //   uint256(0),
    //   uint256(0),
    //   address(0),
    //   address(0),
    //   address(0)
    // );

    // captureTokenViaProxy(proxyRegistry.proxies(msg.sender), address(wmatic), borrowAmount);
    // wmatic.transferFrom(msg.sender, 100);
    wh(94);
    flashLoan.flashLoan(address(this), 1000, "");
  }

  function wh(uint256 id) public {
    emit Where(msg.sender, id);
  }

  function closePosition2() external {
    // bytes memory flashloanData = abi.encode(
    //   msg.sender,
    //   uint256(1),
    //   uint256(0),
    //   uint256(0),
    //   uint256(0),
    //   address(0),
    //   address(0),
    //   address(0)
    // );

    bytes memory data = abi.encode(getProxy());
    wh(115);

    arth.approve(address(flashLoan), 1000);
    flashLoan.flashLoan(address(this), 1000, data);
    // wmatic.transfer(msg.sender, 100);
    // flashLoan.flashLoan(address(this), borrowAmount, flashloanData);
  }

  function getProxy() public view returns (address) {
    return address(proxyRegistry.proxies(msg.sender));
  }

  function onFlashLoan(
    address initiator,
    uint256 flashloanedAmount,
    uint256 fee,
    bytes calldata data
  ) external override returns (bytes32) {
    require(msg.sender == address(flashLoan), "untrusted lender");
    // require(initiator == address(this), "not contract");

    // decode the data
    address proxy = abi.decode(data, (address));

    wh(138);
    bytes4 CALLBACK_SELECTOR = bytes4(keccak256("wh(uint256)"));
    DSProxy(proxy).execute(address(this), abi.encodeWithSelector(CALLBACK_SELECTOR, 142));
    // // decode the data
    // (
    //   address who,
    //   uint256 action,
    //   uint256 maxFee,
    //   uint256 debt,
    //   uint256 collateralAmount,
    //   address upperHint,
    //   address lowerHint,
    //   address frontEndTag
    // ) = abi.decode(data, (address, uint256, uint256, uint256, uint256, address, address, address));

    // // open or close the loan position
    // if (action == 0) {
    //   onFlashloanOpenPosition(
    //     who,
    //     flashloanedAmount,
    //     maxFee,
    //     debt,
    //     collateralAmount,
    //     upperHint,
    //     lowerHint,
    //     frontEndTag
    //   );
    // } else onFlashloanClosePosition(who);

    return keccak256("FlashMinter.onFlashLoan");
  }

  function onFlashloanOpenPosition(
    address who,
    uint256 flashloanedAmount,
    uint256 maxFee,
    uint256 debt,
    uint256 collateralAmount,
    address upperHint,
    address lowerHint,
    address frontEndTag
  ) internal {
    // step 1: sell arth for collateral
    sellARTH(flashloanedAmount, collateralAmount);

    // step 2: open loan using the collateral
    // openLoan(
    //   proxyRegistry.proxies(who),
    //   borrowerOperations,
    //   maxFee,
    //   debt,
    //   collateralAmount,
    //   upperHint,
    //   lowerHint,
    //   frontEndTag,
    //   address(arth)
    // );

    // over here we will have a open loan with collateral and dsproxy would
    // send us back the minted arth

    // step 3: payback the loan..
  }

  function onFlashloanClosePosition(address who) internal {
    captureTokenViaProxy(proxyRegistry.proxies(who), address(wmatic), 100);
    // 1. use the flashloan'd ARTH to payback the debt
    // closeLoan(proxyRegistry.proxies(who), borrowerOperations, address(wmatic));

    // 2. get the collateral and swap back to arth
    // uint256 collateralAmount = 100;
    // buyARTH(collateralAmount, 0);

    // 3. payback the loan..
  }

  function sellARTH(uint256 _arthAmount, uint256 _minSwapAmount) internal returns (uint256) {
    arth.approve(address(uniswapRouter), _arthAmount);

    address[] memory path = new address[](3);
    path[0] = address(arth);
    path[1] = address(usdc);
    path[2] = address(wmatic);

    uint256[] memory amountsOut = uniswapRouter.swapExactTokensForTokens(
      _arthAmount,
      _minSwapAmount,
      path,
      address(this),
      block.timestamp
    );

    return amountsOut[amountsOut.length - 1];
  }

  function buyARTH(uint256 _collateralAmount, uint256 _minSwapAmount) internal returns (uint256) {
    wmatic.approve(address(uniswapRouter), _collateralAmount);

    address[] memory path = new address[](2);
    path[0] = address(wmatic);
    path[1] = address(usdc);
    // path[2] = address(arth);

    uint256[] memory amountsOut = uniswapRouter.swapExactTokensForTokens(
      _collateralAmount,
      _minSwapAmount,
      path,
      address(this),
      block.timestamp
    );

    return amountsOut[amountsOut.length - 1];
  }
}
