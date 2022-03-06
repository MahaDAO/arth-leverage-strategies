// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ILeverageStrategy} from "../interfaces/ILeverageStrategy.sol";
import {IFlashLoan} from "../interfaces/IFlashLoan.sol";
import {IFlashBorrower} from "../interfaces/IFlashBorrower.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract CurveHelpers {
  using SafeMath for uint256;
}
