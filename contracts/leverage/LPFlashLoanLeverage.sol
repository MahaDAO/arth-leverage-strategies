// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import "../Dependencies/CheckContract.sol";
// import "../Interfaces/IBorrowerOperations.sol";
// import "../Dependencies/IUniswapV2Router02.sol";
// import "../Dependencies/IUniswapV2Pair.sol";
// import "../Dependencies/IERC20.sol";
// import "../Dependencies/SafeMath.sol";
// import "../Interfaces/IFlashLoan.sol";

// contract LPFlashLoanLeverage is CheckContract {
//     using SafeMath for uint256;

//     address immutable arth;
//     address immutable pair;
//     address immutable token0;
//     address immutable token1;
//     address[] public arthToToken0Path;
//     address[] public arthToToken1Path;

//     IFlashLoan public flashLoan;
//     IUniswapV2Router02 public uniswapRouter;
//     IBorrowerOperations public borrowerOperations;

//     constructor(
//         address _pair,
//         address _arth,
//         address[] memory _arthToToken0Path,
//         address[] memory _arthToToken1Path,
//         IFlashLoan _flashLoan,
//         IUniswapV2Router02 _uniswapRouter,
//         IBorrowerOperations _borrowerOperations
//     ) public {
//         CheckContract(_arth);
//         CheckContract(_pair);
//         checkContract(address(_uniswapRouter));
//         CheckContract(address(_flashLoan));
//         checkContract(address(_borrowerOperations));

//         arth = _arth;
//         pair = _pair;
//         token0 = IUniswapV2Pair(_pair).token0();
//         token1 = IUniswapV2Pair(_pair).token1();
//         arthToToken0Path = _arthToToken0Path;
//         arthToToken1Path = _arthToToken1Path;
//         flashLoan = _flashLoan;
//         uniswapRouter = _uniswapRouter;
//         borrowerOperations = _borrowerOperations;
//     }

//     function onFlashLoan(
//         address initiator,
//         uint256 amount,
//         uint256 fee,
//         bytes calldata data
//     ) external returns(bytes32) {
//         require(msg.sender == address(flashLoan), "Untrusted lender");

//         uint256 paybackAmount = amount.add(fee);

//         (
//             uint256 _maxFee,
//             uint256 _LUSDAmount,
//             uint256 _ETHAmount,
//             address _upperHint,
//             address _lowerHint,
//             address _frontEndTag
//         ) = abi.decode(
//             data,
//             (uint256,uint256,uint256,address,address,address)
//         );

//         uint256 arthToSwap = amount.div(2);
//         uint256 token0Out = _swapARTHForToken(arthToToken0Path, arthToSwap);
//         uint256 token1Out = _swapARTHForToken(arthToToken1Path, arthToSwap);
//         uint256 liquidityOut = _addLiquidity(token0Out, token1Out);

//         IERC20(pair).transferFrom(initiator, address(this), _ETHAmount.sub(liquidityOut));
//         IERC20(pair).approve(address(borrowerOperations), _ETHAmount);

//         // 3. Borrow ARTH.
//         borrowerOperations.openTrove(
//             _maxFee,
//             _LUSDAmount,
//             _ETHAmount,
//             _upperHint,
//             _lowerHint,
//             _frontEndTag
//         );
//         require(
//             IERC20(arth).balanceOf(address(this)) >= paybackAmount,
//             "Wrong payback amount"
//         );
//         IERC20(arth).approve(address(flashLoan), paybackAmount);

//         return keccak256("FlashMinter.onFlashLoan");
//     }

//     function _swapARTHForToken(
//         address[] memory path,
//         uint256 _arthAmount
//     ) internal returns (uint256) {
//         IERC20(arth).approve(address(uniswapRouter), _arthAmount);

//         uint256[] memory expectedAmountsOut = uniswapRouter.getAmountsOut(
//             _arthAmount,
//             path
//         );

//         uint256[] memory amountsOut = uniswapRouter.swapExactTokensForTokens(
//             _arthAmount,
//             expectedAmountsOut[expectedAmountsOut.length - 1],
//             path,
//             address(this),
//             block.timestamp
//         );

//         return amountsOut[amountsOut.length - 1];
//     }

//     function _addLiquidity(
//         uint256 _token0Amount,
//         uint256 _token1Amount
//     ) internal returns (uint256) {
//         IERC20(token0).approve(address(uniswapRouter), _token0Amount);
//         IERC20(token1).approve(address(uniswapRouter), _token1Amount);

//         (,, uint256 liquidity) = uniswapRouter.addLiquidity(
//             token0,
//             token1,
//             _token0Amount,
//             _token1Amount,
//             _token0Amount,
//             _token1Amount,
//             address(this),
//             block.timestamp
//         );

//         return liquidity;
//     }
// }
