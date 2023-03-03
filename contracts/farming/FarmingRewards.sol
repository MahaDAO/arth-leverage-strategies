// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import "../interfaces/IBorrowerOperations.sol";
import "../interfaces/IPriceFeed.sol";
import "../interfaces/ITroveManager.sol";
import "../interfaces/INonfungiblePositionManager.sol";


contract FarmingRewards is Ownable {
    IBorrowerOperations public borrowerOperations;
    IPriceFeed public priceFeed;
    ITroveManager public troveManager;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    uint256 constant ICR = 2000000000000000000; // 200 %
    uint24 public constant poolFee = 10000;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ARTH = 0x8CC0F052fff7eaD7f2EdCCcaC895502E884a8a71;
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    struct Deposit {
        address owner;
        uint128 liquidity;
    }

    mapping(uint256 => Deposit) public deposits;

    event DepositEvent(uint256 tokenId, address owner, uint128 liquidity);

    constructor(
        IBorrowerOperations borrowerOperations_,
        IPriceFeed _priceFeed,
        ITroveManager _troveManager,
        INonfungiblePositionManager nonfungiblePositionManager_
    ) {
        borrowerOperations = borrowerOperations_;
        priceFeed = _priceFeed;
        troveManager = _troveManager;
        nonfungiblePositionManager = nonfungiblePositionManager_;
    }

    function deposit(address onBehalf_) payable external {
        uint256 consumeETH_ = _mintARTH(msg.value);
        uint256 arthBal_ = IERC20(ARTH).balanceOf(msg.sender);
        IWETH(WETH).deposit{value: msg.value - consumeETH_}();
        _mintNewPosition(msg.value - consumeETH_, arthBal_, onBehalf_);
    }

    function withdraw(uint256 tokenId_) external {
        _removeLP(tokenId_);
        borrowerOperations.closeTrove();
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external virtual returns (bytes4) {
        // get position information

        _createDeposit(operator, tokenId);

        return this.onERC721Received.selector;
    }

    // /// ---------- internal functions------------ ////

    function _getNetBorrowingAmount() private view returns (uint256 amount_) {
        uint256 borrowingRate_ = troveManager.getBorrowingRateWithDecay();
        uint256 debt_ = borrowerOperations.MIN_NET_DEBT();
        assembly {
            amount_ := div(mul(debt_, 1000000000000000000), add(borrowingRate_, 1000000000000000000))
        }
    }

    function _mintARTH(uint256 userValue_) private returns(uint256 value_) {
        uint256 minDebt_ = _getNetBorrowingAmount();
        uint256 price_ = priceFeed.fetchPrice();
        uint256 totalDebt_ = troveManager.getBorrowingFee(minDebt_) + borrowerOperations.getCompositeDebt(minDebt_);
        value_ = ICR * totalDebt_ / price_;
        require(userValue_ >= value_, "insufficient balance");
        borrowerOperations.openTrove{value: value_} (
            1000000000000000000,        // max fee
            minDebt_,
            address(0),                 // upper hint
            address(0),                 // lower hint
            address(0)                  // frontend tag
        );
    }

    function _mintNewPosition(uint256 inputWETH_, uint256 inputARTH_, address onBehalf_)
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
        TransferHelper.safeApprove(ARTH, address(nonfungiblePositionManager), inputARTH_);
        TransferHelper.safeApprove(WETH, address(nonfungiblePositionManager), inputWETH_);

        INonfungiblePositionManager.MintParams memory params =
            INonfungiblePositionManager.MintParams({
                token0: ARTH,
                token1: WETH,
                fee: poolFee,
                tickLower: MIN_TICK,
                tickUpper: MAX_TICK,
                amount0Desired: inputARTH_,
                amount1Desired: inputWETH_,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (tokenId, liquidity, amountARTH, amountWETH) = nonfungiblePositionManager.mint(params);
        // Create a deposit
        _createDeposit(onBehalf_, tokenId);

        // Remove allowance and refund in both assets.
        if (amountARTH < inputARTH_) {
            TransferHelper.safeApprove(ARTH, address(nonfungiblePositionManager), 0);
            uint256 refund0 = inputARTH_ - amountARTH;
            TransferHelper.safeTransfer(ARTH, msg.sender, refund0);
        }

        if (amountWETH < inputWETH_) {
            TransferHelper.safeApprove(WETH, address(nonfungiblePositionManager), 0);
            uint256 refund1 = inputWETH_ - amountWETH;
            IWETH(WETH).withdraw(refund1);
            payable(msg.sender).transfer(refund1);
        }
    }

    function _createDeposit(address owner, uint256 tokenId) private {
        (, , , , , , , uint128 liquidity, , , , ) =
            nonfungiblePositionManager.positions(tokenId);

        // set the owner and data for position
        // operator is msg.sender
        deposits[tokenId] = Deposit({owner: owner, liquidity: liquidity});
        emit DepositEvent(tokenId, owner, liquidity);
    }

    function _removeLP(uint256 tokenId) private returns (uint256 amount0, uint256 amount1) {
        // caller must be the owner of the NFT
        require(msg.sender == deposits[tokenId].owner, 'Not the owner');

        // amount0Min and amount1Min are price slippage checks
        // if the amount received after burning is not greater than these minimums, transaction will fail
        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: 0,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(params);
    }

}