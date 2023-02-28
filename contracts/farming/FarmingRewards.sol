// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import "../interfaces/IBorrowerOperations.sol";
import "../interfaces/IUniswapV3SwapRouter.sol";
import "../interfaces/IPriceFeed.sol";
import "../interfaces/ITroveManager.sol";
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol';


contract FarmingRewards is Ownable {
    IBorrowerOperations public borrowerOperations;
    IUniswapV3SwapRouter public router;
    IPriceFeed public priceFeed;
    ITroveManager public troveManager;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    uint256 constant ICR = 2000000000000000000; // 200 %
    uint24 public constant poolFee = 10000;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ARTH =  0x8CC0F052fff7eaD7f2EdCCcaC895502E884a8a71;

    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    mapping(uint256 => Deposit) public deposits;

    constructor(
        IBorrowerOperations borrowerOperations_,
        IUniswapV3SwapRouter _router,
        IPriceFeed _priceFeed,
        ITroveManager _troveManager,
        INonfungiblePositionManager nonfungiblePositionManager_
    ) {
        borrowerOperations = borrowerOperations_;
        router = _router;
        priceFeed = _priceFeed;
        troveManager = _troveManager;
        nonfungiblePositionManager = nonfungiblePositionManager_;
    }

    function deposit(address onBehalf) payable external {
        _mintARTH(msg.value);
        uint256 arthBal_ = ARTH.balanceOf(msg.sender);
        uint256 ethBal_ = WETH.deposit(msg.sender.balance)
        _mintNewPosition();
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        // get position information

        _createDeposit(operator, tokenId);

        return this.onERC721Received.selector;
    }

    /// ---------- internal functions------------ ////

    function _getNetBorrowingAmount() private returns (uint256 amount_) {
        uint256 borrowingRate_ = troveManager.getBorrowingRateWithDecay();
        assembly {
            amount_ := div(mul(borrowerOperations.MIN_NET_DEBT(), 1000000000000000000), add(borrowingRate_, 1000000000000000000))
        }
    }

    function _mintARTH(uint256 userValue_) private {
        uint256 minDebt_ = _getNetBorrowingAmount();
        uint256 price_ = priceFeed.fetchPrice();
        uint256 totalDebt_ = troveManager.getBorrowingFee(minDebt_) + borrowerOperations.getCompositeDebt(minDebt_);
        uint256 value_ = ICR * totalDebt_ / price_;
        require(userValue_ >= value_, "insufficient balance");
        borrowerOperations.openTrove{value: value_}(
            1000000000000000000,        // max fee
            minDebt_,
            address(0),                 // upper hint
            address(0),                 // lower hint
            address(0),                 // frontend tag
        );
    }

     function _mintNewPosition(uint256 WETHAmount_, uint256 ARTHAmount_)
        private
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amountARTH,
            uint256 amountWETH
        )
    {
        // For this example, we will provide equal amounts of liquidity in both assets.
        // Providing liquidity in both assets means liquidity will be earning fees and is considered in-range.

        // Approve the position manager
        TransferHelper.safeApprove(ARTH, address(nonfungiblePositionManager), ARTHAmount_);
        TransferHelper.safeApprove(WETH, address(nonfungiblePositionManager), WETHAmount_);

        INonfungiblePositionManager.MintParams memory params =
            INonfungiblePositionManager.MintParams({
                token0: ARTH,
                token1: WETH,
                fee: poolFee,
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                amount0Desired: ARTHAmount_,
                amount1Desired: WETHAmount_,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (tokenId, liquidity, amountARTH, amountWETH) = nonfungiblePositionManager.mint(params);

        // Create a deposit
        _createDeposit(msg.sender, tokenId);

        // Remove allowance and refund in both assets.
        if (amountARTH < ARTHAmount_) {
            TransferHelper.safeApprove(ARTH, address(nonfungiblePositionManager), 0);
            uint256 refund0 = amount0ToMint - amount0;
            TransferHelper.safeTransfer(ARTH, msg.sender, refund0);
        }

        if (amountWETH < WETHAmount_) {
            TransferHelper.safeApprove(WETH, address(nonfungiblePositionManager), 0);
            uint256 refund1 = amount1ToMint - amount1;
            IWETH.withdraw(refund1);
            msg.sender.transfer(refund1);
        }
    }

    function _createDeposit(address owner, uint256 tokenId) private {
        (, , address token0, address token1, , , , uint128 liquidity, , , , ) =
            nonfungiblePositionManager.positions(tokenId);

        // set the owner and data for position
        // operator is msg.sender
        deposits[tokenId] = Deposit({owner: owner, liquidity: liquidity, token0: token0, token1: token1});
    }
}