// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {DSProxy} from "../proxy/DSProxy.sol";
import {IBorrowerOperations} from "../interfaces/IBorrowerOperations.sol";
import {IFlashBorrower} from "../interfaces/IFlashBorrower.sol";
import {IFlashLoan} from "../interfaces/IFlashLoan.sol";
import {ILeverageStrategy} from "../interfaces/ILeverageStrategy.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ProxyHelpers} from "./ProxyHelpers.sol";

abstract contract TroveHelpers is ProxyHelpers {
  using SafeMath for uint256;
  bytes4 private constant OPEN_LOAN_SELECTOR =
    bytes4(keccak256("openTrove(uint256,uint256,uint256,address,address,address)"));

  bytes4 private constant CLOSE_LOAN_SELECTOR =
    bytes4(keccak256("openTrove(uint256,uint256,uint256,address,address,address)"));

  function openLoan(
    DSProxy userProxy,
    address borrowerOperations,
    uint256 maxFee,
    uint256 debt,
    uint256 collateralAmount,
    address upperHint,
    address lowerHint,
    address frontEndTag,
    address returnTokenAddress
  ) internal {
    bytes memory openLoanData = abi.encodeWithSelector(
      OPEN_LOAN_SELECTOR,
      maxFee,
      debt,
      collateralAmount,
      upperHint,
      lowerHint,
      frontEndTag
    );

    // open loan using the user's proxy
    userProxy.execute(borrowerOperations, openLoanData);

    // send the arth back to the flash loan contract
    captureTokenViaProxy(userProxy, returnTokenAddress, debt);
  }

  function closeLoan(
    DSProxy userProxy,
    address borrowerOperations,
    address returnTokenAddress
  ) internal {
    // close loan using the user's proxy
    bytes memory closeLoanData = abi.encodeWithSelector(CLOSE_LOAN_SELECTOR);
    userProxy.execute(borrowerOperations, closeLoanData);

    // send the collateral back to the flash loan contract
    uint256 bal = IERC20(returnTokenAddress).balanceOf(address(userProxy));
    captureTokenViaProxy(userProxy, returnTokenAddress, bal);
  }
}
