// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ILeverageStrategy} from "../interfaces/ILeverageStrategy.sol";
import {IFlashLoan} from "../interfaces/IFlashLoan.sol";
import {TroveHelpers} from "../helpers/TroveHelpers.sol";
import {IFlashBorrower} from "../interfaces/IFlashBorrower.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WMaticExposure is ILeverageStrategy, IFlashBorrower, TroveHelpers {
    using SafeMath for uint256;

    event OpenPosition(uint256 amount, address who);

    IFlashLoan public flashLoan;
    address public borrowerOperations;

    //     IUniswapV2Router02 public uniswapRouter;
    //     IBorrowerOperations public borrowerOperations;

    constructor(address _flashloan, address _borrowerOperations) {
        flashLoan = IFlashLoan(_flashloan);
        borrowerOperations = _borrowerOperations;
    }

    function openPosition(uint256 amountIn, uint256 borrowAmount) external override returns (bool) {
        emit OpenPosition(amountIn + borrowAmount, msg.sender);
        flashLoan.flashLoan(address(this), borrowAmount, "o");
        return true;
    }

    function closePosition() external override {
        flashLoan.flashLoan(address(this), 0, "c");
    }

    function calculateSlippage(uint256 amountIn, uint256 borrowAmount) external override {
        // nothing
        emit OpenPosition(amountIn + borrowAmount, msg.sender);
    }

    function onFlashLoan(
        address initiator,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == address(flashLoan), "Untrusted lender");

        // uint256 paybackAmount = amount.add(fee);
        // (
        //     uint256 _maxFee,
        //     uint256 _LUSDAmount,
        //     uint256 _ETHAmount,
        //     address _upperHint,
        //     address _lowerHint,
        //     address _frontEndTag
        // ) = abi.decode(
        //     data,
        //     (uint256,uint256,uint256,address,address,address)
        // );

        // uint256 arthToSwap = amount.div(2);
        // uint256 token0Out = _swapARTHForToken(arthToToken0Path, arthToSwap);
        // uint256 token1Out = _swapARTHForToken(arthToToken1Path, arthToSwap);
        // uint256 liquidityOut = _addLiquidity(token0Out, token1Out);

        // IERC20(pair).transferFrom(initiator, address(this), _ETHAmount.sub(liquidityOut));
        // IERC20(pair).approve(address(borrowerOperations), _ETHAmount);

        // // 3. Borrow ARTH.
        // borrowerOperations.openTrove(
        //     _maxFee,
        //     _LUSDAmount,
        //     _ETHAmount,
        //     _upperHint,
        //     _lowerHint,
        //     _frontEndTag
        // );
        // require(
        //     IERC20(arth).balanceOf(address(this)) >= paybackAmount,
        //     "Wrong payback amount"
        // );
        // IERC20(arth).approve(address(flashLoan), paybackAmount);

        onFlashloanOpenPosition();

        return keccak256("FlashMinter.onFlashLoan");
    }

    function onFlashloanOpenPosition() internal {}

    function onFlashloanClosePosition() internal {
        // 1. use the flashloan to payback the debt
        closeLoan(borrowerOperations);

        // 2. get the collateral and swap back to arth
    }
}
