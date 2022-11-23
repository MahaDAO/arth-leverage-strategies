// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {IUniswapV3Pool} from "../../interfaces/IUniswapV3Pool.sol";
import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
import {IUniswapV3SwapRouter} from "../../interfaces/IUniswapV3SwapRouter.sol";
import {StakingRewardsChild} from "./StakingRewardsChild.sol";
import {INonfungiblePositionManager} from "../../interfaces/INonfungiblePositionManager.sol";
import {MerkleWhitelist} from "./MerkleWhitelist.sol";
import {IPriceFeed} from "../../interfaces/IPriceFeed.sol";
import {IARTHETHRouter} from "../../interfaces/IARTHETHRouter.sol";
import "hardhat/console.sol";
import {Multicall} from "../../utils/Multicall.sol";

contract ARTHETHTroveLP is StakingRewardsChild, MerkleWhitelist, Multicall {
    using SafeMath for uint256;

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    struct Position {
        uint256 uniswapNftId;
        uint256 eth;
        uint256 coll;
        uint256 debt;
        uint128 liquidity;
        uint256 arthInUniswap;
        uint256 ethInUniswap;
    }

    struct TroveParams {
        uint256 maxFee;
        address upperHint;
        address lowerHint;
        uint256 ethAmount;
        uint256 arthAmount;
    }

    struct WithdrawTroveParams {
        uint256 maxFee;
        address upperHint;
        address lowerHint;
    }

    struct UniswapPositionMintParams {
        int24 tickLower;
        int24 tickUpper;
        uint256 ethAmountMin;
        uint256 ethAmountDesired;
        uint256 arthAmountMin;
        uint256 arthAmountDesired;
    }

    struct UniswapPositionDecreaseLiquidity {
        uint256 tokenId;
        uint128 liquidity;
        uint256 arthOutMin;
        uint256 ethOutMin;
    }

    struct WhitelistParams {
        uint256 rootId;
        bytes32[] proof;
    }

    uint24 public fee;
    bool public isARTHToken0;
    mapping(address => Position) public positions;

    IERC20 public arth;
    IERC20 public weth;
    IUniswapV3Pool public pool;

    address private _arth;
    address private _weth;
    address private me;

    uint256 public mintCollateralRatio = 3 * 1e18; // 300% CR

    IPriceFeed public priceFeed;
    IBorrowerOperations public borrowerOperations;
    IARTHETHRouter public arthRouter;
    INonfungiblePositionManager public uniswapNFTManager;

    // TODO: the scenario when the trove gets liquidated?

    constructor(
        address _borrowerOperations,
        address _uniswapNFTManager,
        address __arth,
        address __maha,
        address __weth,
        uint24 _fee,
        address _arthRouter,
        address _priceFeed,
        address _pool
    ) StakingRewardsChild(__maha) {
        fee = _fee;

        arth = IERC20(__arth);
        weth = IERC20(__weth);
        _arth = __arth;
        _weth = __weth;

        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        arthRouter = IARTHETHRouter(_arthRouter);
        uniswapNFTManager = INonfungiblePositionManager(_uniswapNFTManager);
        priceFeed = IPriceFeed(_priceFeed);
        pool = IUniswapV3Pool(_pool);

        arth.approve(_uniswapNFTManager, type(uint256).max);
        arth.approve(_arthRouter, type(uint256).max);

        isARTHToken0 = pool.token0() == _arth;
        me = address(this);
    }

    /// @notice admin-only function to open a trove; needed to initialize the contract
    function openTrove(
        uint256 _maxFee,
        uint256 _arthAmount,
        address _upperHint,
        address _lowerHint,
        address _frontEndTag
    ) external payable onlyOwner nonReentrant {
        require(msg.value > 0, "no eth");

        // Open the trove.
        borrowerOperations.openTrove{value: msg.value}(
            _maxFee,
            _arthAmount,
            _upperHint,
            _lowerHint,
            _frontEndTag
        );
    }

    /// @notice admin-only function to close the trove; normally not needed if the campaign keeps on running
    function closeTrove(uint256 arthNeeded) external payable onlyOwner nonReentrant {
        // Get the ARTH needed to close the loan.
        arth.transferFrom(msg.sender, me, arthNeeded);

        // Close the trove.
        borrowerOperations.closeTrove();
    }

    function deposit(
        TroveParams memory troveParams,
        UniswapPositionMintParams memory uniswapPoisitionMintParams
    )
        public
        payable
        // WhitelistParams memory whitelistParams
        /* checkWhitelist(msg.sender, whitelistParams.rootId, whitelistParams.proof)*/
        nonReentrant
    {
        // Check that position is not already open.
        console.log("entering deposit(...)");
        require(positions[msg.sender].uniswapNftId == 0, "Position already open");

        // Check that we are receiving appropriate amount of ETH and
        // Mint the new strategy NFT. The ETH amount should cover for
        // the loan and adding liquidity in the uni v3 pool.
        require(
            msg.value == uniswapPoisitionMintParams.ethAmountDesired.add(troveParams.ethAmount),
            "Invalid ETH amount"
        );
        require(
            priceFeed.fetchPrice().mul(troveParams.ethAmount).div(troveParams.arthAmount) >=
                mintCollateralRatio,
            "CR must be > 299%"
        );

        // 2. Mint ARTH and track ARTH balance changes due to this current tx.
        console.log("deposit(...) - adjustTrove");
        borrowerOperations.adjustTrove{value: troveParams.ethAmount}(
            troveParams.maxFee,
            0, // No coll withdrawal.
            troveParams.arthAmount, // Mint ARTH.
            true, // Debt increasing.
            troveParams.upperHint,
            troveParams.lowerHint
        );

        // 3. Adding liquidity in the ARTH/ETH pair.
        console.log("deposit(...) - uniswapNFTManager.mint");
        INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager
            .MintParams({
                token0: isARTHToken0 ? _arth : _weth,
                token1: isARTHToken0 ? _weth : _arth,
                fee: fee,
                tickLower: uniswapPoisitionMintParams.tickLower,
                tickUpper: uniswapPoisitionMintParams.tickUpper,
                amount0Desired: isARTHToken0
                    ? uniswapPoisitionMintParams.arthAmountDesired
                    : uniswapPoisitionMintParams.ethAmountDesired,
                amount1Desired: isARTHToken0
                    ? uniswapPoisitionMintParams.ethAmountDesired
                    : uniswapPoisitionMintParams.arthAmountDesired,
                amount0Min: isARTHToken0
                    ? uniswapPoisitionMintParams.arthAmountMin
                    : uniswapPoisitionMintParams.ethAmountMin,
                amount1Min: isARTHToken0
                    ? uniswapPoisitionMintParams.ethAmountMin
                    : uniswapPoisitionMintParams.arthAmountMin,
                recipient: me,
                deadline: block.timestamp
            });
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = uniswapNFTManager
            .mint{value: uniswapPoisitionMintParams.ethAmountDesired}(mintParams);

        // 4. Record the position.
        console.log("deposit(...) - Position");
        positions[msg.sender] = Position({
            eth: troveParams.ethAmount.add(isARTHToken0 ? amount1 : amount0),
            coll: troveParams.ethAmount,
            debt: troveParams.arthAmount,
            uniswapNftId: tokenId,
            liquidity: liquidity,
            arthInUniswap: isARTHToken0 ? amount0 : amount1,
            ethInUniswap: isARTHToken0 ? amount1 : amount0
        });

        // 6. Record the staking in the staking contract for maha rewards
        console.log("deposit(...) - _stake");
        _stake(msg.sender, positions[msg.sender].eth);

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(
        WithdrawTroveParams memory troveParams,
        uint256 amountETHswapMaximum,
        uint256 ethOutMin,
        UniswapPositionDecreaseLiquidity memory decreaseLiquidityParams
    ) public payable nonReentrant {
        require(positions[msg.sender].uniswapNftId != 0, "Position not open");

        // 1. Burn the strategy NFT, fetch position details,
        // remove the position and withdraw you stake for stopping further rewards.
        Position memory position = positions[msg.sender];
        _withdraw(msg.sender, position.eth);
        delete positions[msg.sender];

        // 2. Claim the fees.
        _getReward();
        _collectFees(position.uniswapNftId);

        // 3. Remove the LP for ARTH/ETH.
        uint256 ethAmountOut;
        uint256 arthAmountOut;
        require(decreaseLiquidityParams.liquidity == position.liquidity, "Liquidity not same");
        require(decreaseLiquidityParams.tokenId == position.uniswapNftId, "Token id not same");
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: decreaseLiquidityParams.tokenId,
                liquidity: decreaseLiquidityParams.liquidity,
                amount0Min: isARTHToken0
                    ? decreaseLiquidityParams.arthOutMin
                    : decreaseLiquidityParams.ethOutMin,
                amount1Min: isARTHToken0
                    ? decreaseLiquidityParams.ethOutMin
                    : decreaseLiquidityParams.arthOutMin,
                deadline: block.timestamp
            });
        if (isARTHToken0) {
            (arthAmountOut, ethAmountOut) = uniswapNFTManager.decreaseLiquidity(params);
        } else {
            (ethAmountOut, arthAmountOut) = uniswapNFTManager.decreaseLiquidity(params);
        }

        // 4. Check if the ARTH we received is less.
        if (arthAmountOut < position.debt) {
            // Then we swap the ETH for remaining ARTH in the ARTH/ETH pool.
            uint256 ethUsed = arthRouter.swapETHtoARTH{value: amountETHswapMaximum}(
                me,
                amountETHswapMaximum
            );
            ethAmountOut = ethAmountOut.sub(ethUsed); // Decrease the amount of ETH we have, since we swapped it for ARTH.
        }

        // 5. Adjust the trove, to remove collateral.
        borrowerOperations.adjustTrove(
            troveParams.maxFee,
            position.coll,
            position.debt,
            false,
            troveParams.upperHint,
            troveParams.lowerHint
        );

        require(ethAmountOut >= ethOutMin, "not enough eth out");
        emit Withdrawal(msg.sender, position.eth);
    }

    function flush(
        address to,
        bool shouldSwapARTHForETH,
        uint256 amountOutMin
    ) external {
        if (shouldSwapARTHForETH) arthRouter.swapARTHtoETH(me, arth.balanceOf(me), amountOutMin);

        uint256 arthBalance = arth.balanceOf(me);
        if (arthBalance > 0) arth.transfer(to, arthBalance);

        uint256 ethBalance = me.balance;
        if (ethBalance > 0) {
            (
                bool success, /* bytes memory data */

            ) = to.call{value: ethBalance}("");
            require(success, "ETH transfer failed");
        }
    }

    function collectRewards() public payable nonReentrant {
        Position memory position = positions[msg.sender];
        require(position.uniswapNftId != 0, "Position not open");

        _getReward();
        _collectFees(position.uniswapNftId);
    }

    function _collectFees(uint256 uniswapNftId) internal {
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager
            .CollectParams({
                recipient: me,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max,
                tokenId: uniswapNftId
            });

        // Trigger the fee collection for the nft owner.
        uniswapNFTManager.collect(collectParams);
    }

    function setRouter(address target) external payable onlyOwner {
        arthRouter = IARTHETHRouter(target);
    }

    /// @dev in case admin needs to execute some calls directly
    function emergencyCall(address target, bytes memory signature) external payable onlyOwner {
        (bool success, bytes memory response) = target.call{value: msg.value}(signature);
        require(success, string(response));
    }

    function getPoolData()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint160 liquidity
        )
    {
        (
            uint160 _sqrtPriceX96,
            int24 _tick,
            uint16 _observationIndex,
            uint16 _observationCardinality,
            uint16 _observationCardinalityNext,
            uint8 _feeProtocol,
            bool _unlocked
        ) = pool.slot0();

        return (_sqrtPriceX96, _tick, _sqrtPriceX96);
    }

    function getTickSpacing() external view returns (int24) {
        return pool.tickSpacing();
    }

    function lastGoodPrice() external view returns (uint256) {
        return priceFeed.lastGoodPrice();
    }
}
