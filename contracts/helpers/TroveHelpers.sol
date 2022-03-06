// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ILeverageStrategy} from "../interfaces/ILeverageStrategy.sol";
import {IFlashLoan} from "../interfaces/IFlashLoan.sol";
import {IFlashBorrower} from "../interfaces/IFlashBorrower.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IBorrowerOperations} from "../interfaces/IBorrowerOperations.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";

abstract contract TroveHelpers {
    using SafeMath for uint256;

    function openLoan(
        address borrowerOperations,
        uint256 _maxFee,
        uint256 _debt,
        uint256 _collateralAmount,
        address _upperHint,
        address _lowerHint,
        address _frontEndTag
    ) internal {
        // open loan
        IBorrowerOperations(borrowerOperations).openTrove(
            _maxFee,
            _debt,
            _collateralAmount,
            _upperHint,
            _lowerHint,
            _frontEndTag
        );
    }

    function closeLoan(address borrowerOperations) internal {
        // open loan
        IBorrowerOperations(borrowerOperations).closeTrove();
    }
}
