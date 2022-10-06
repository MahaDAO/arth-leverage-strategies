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
import {ITroveManager} from "../../interfaces/ITroveManager.sol";

contract ARTHETHTroveLP is StakingRewardsChild, MerkleWhitelist {
    using SafeMath for uint256;

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    struct Position {
        uint256 uniswapNftId;
        uint256 eth;
        uint256 coll;
        uint256 debt;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
    }

    struct TroveParams {
        uint256 maxFee;
        address upperHint;
        address lowerHint;
    }

    uint24 public fee;
    mapping(address => Position) public positions;

    IERC20 public arth;
    IERC20 public weth;

    address private _arth;
    address private _weth;
    address private me;

    uint256 public mintCollateralRatio = 3 * 1e18; // 300% CR

    IPriceFeed public priceFeed;
    ITroveManager public troveManager;
    IBorrowerOperations public borrowerOperations;
    IUniswapV3SwapRouter public uniswapV3SwapRouter;
    INonfungiblePositionManager public uniswapNFTManager;
    
    // TODO: the scenario when the trove gets liquidated?

    constructor(
        address _borrowerOperations,
        address _uniswapNFTManager,
        address __arth,
        address __maha,
        address __weth,
        uint24 _fee,
        address _uniswapV3SwapRouter,
        address _priceFeed,
        address _troveManager
    ) StakingRewardsChild(__maha) {
        fee = _fee;

        arth = IERC20(__arth);
        weth = IERC20(__weth);
        _arth = __arth;
        _weth = __weth;

        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        uniswapV3SwapRouter = IUniswapV3SwapRouter(_uniswapV3SwapRouter);
        uniswapNFTManager = INonfungiblePositionManager(_uniswapNFTManager);
        priceFeed = IPriceFeed(_priceFeed);
        troveManager = ITroveManager(_troveManager);

        arth.approve(_uniswapNFTManager, type(uint256).max);

        // assuming token1 = weth; token0 = arth

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

        // Return dust ETH, ARTH.
        _flush(owner(), false);
    }

    /// @notice admin-only function to close the trove; normally not needed if the campaign keeps on running
    function closeTrove(uint256 arthNeeded) external payable onlyOwner nonReentrant {
        // Get the ARTH needed to close the loan.
        arth.transferFrom(msg.sender, me, arthNeeded);

        // Close the trove.
        borrowerOperations.closeTrove();

        // Return dust ARTH, ETH.
        _flush(owner(), false);
    }

    function deposit(
        uint256 arthToMint,
        uint256 ethToLock,
        TroveParams memory troveParams,
        INonfungiblePositionManager.MintParams memory mintParams,
        uint256 rootId,
        bytes32[] memory proof
    ) public payable checkWhitelist(msg.sender, rootId, proof) nonReentrant {
        require(positions[msg.sender].uniswapNftId == 0, "Position already open");

        // Check that we are receiving appropriate amount of ETH and
        // Mint the new strategy NFT. The ETH amount should cover for
        // the loan and adding liquidity in the uni v3 pool.
        require(msg.value == mintParams.amount1Desired.add(ethToLock), "Invalid ETH amount");

        // Need to make sure that the collateral ratio is exactly 300%
        uint256 price = priceFeed.fetchPrice();
        (uint256 debt, uint256 coll,,) = troveManager.getEntireDebtAndColl(me);
        coll = coll.add(ethToLock);
        debt = debt.add(arthToMint);
        require(price.mul(coll).div(debt) >= mintCollateralRatio, "CR must be > 299%");

        // 2. Mint ARTH and track ARTH balance changes due to this current tx.
        borrowerOperations.adjustTrove{value: ethToLock}(
            troveParams.maxFee,
            0, // No coll withdrawal.
            arthToMint, // Mint ARTH.
            true, // Debt increasing.
            troveParams.upperHint,
            troveParams.lowerHint
        );

        // 3. Adding liquidity in the ARTH/ETH pair.
        mintParams.fee = fee;
        mintParams.recipient = me;
        mintParams.token0 = _arth;
        mintParams.token1 = _weth;
        mintParams.deadline = block.timestamp;
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = uniswapNFTManager
            .mint{value: mintParams.amount1Desired}(mintParams);

        // 4. Record the position.
        positions[msg.sender] = Position({
            eth: (ethToLock + amount1),
            coll: ethToLock,
            debt: arthToMint,
            uniswapNftId: tokenId,
            liquidity: liquidity,
            amount0: amount0,
            amount1: amount1
        });

        // 5. Refund any dust left.
        _flush(msg.sender, false);

        // 6. Record the staking in the staking contract for maha rewards
        _stake(msg.sender, positions[msg.sender].eth);

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(
        TroveParams memory troveParams,
        uint256 amountETHswapMaximum,
        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseLiquidityParams
    ) public payable nonReentrant {
        require(positions[msg.sender].uniswapNftId != 0, "Position not open");

        // 1. Burn the strategy NFT, fetch position details and remove the position.
        Position memory position = positions[msg.sender];
        _withdraw(msg.sender, position.eth);
        delete positions[msg.sender];

        // 2. Claim the fees.
        _collectFees(position.uniswapNftId);

        // 3. Remove the LP for ARTH/ETH.
        decreaseLiquidityParams.deadline = block.timestamp;
        decreaseLiquidityParams.liquidity = position.liquidity;
        decreaseLiquidityParams.tokenId = position.uniswapNftId;
        (uint256 amount0, uint256 amount1) = uniswapNFTManager.decreaseLiquidity(
            decreaseLiquidityParams
        );

        // 4. Check if the ARTH we received is less.
        if (amount0 < position.debt) {
            // Then we swap the ETH for remaining ARTH in the ARTH/ETH pool.
            uint256 arthNeeded = position.debt.sub(amount0);
            IUniswapV3SwapRouter.ExactOutputSingleParams memory params = IUniswapV3SwapRouter
                .ExactOutputSingleParams({
                    tokenIn: _weth,
                    tokenOut: _arth,
                    fee: fee,
                    recipient: me,
                    deadline: block.timestamp,
                    amountOut: arthNeeded,
                    amountInMaximum: amountETHswapMaximum, // TODO: need to estimate this from the frontend
                    sqrtPriceLimitX96: 0
                });
            uint256 amountInNeeded = uniswapV3SwapRouter.exactOutputSingle(params);
            amount1 = amount1.sub(amountInNeeded); // Decrease the amount of ETH we have, since we swapped it for ARTH.
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

        // 6. Flush, send back the amount received with dust.
        _flush(msg.sender, true);

        emit Withdrawal(msg.sender, position.eth);
    }

    function _flush(address to, bool shouldSwapARTHForETH) internal {
        if (shouldSwapARTHForETH) {
            IUniswapV3SwapRouter.ExactInputSingleParams memory params = IUniswapV3SwapRouter
                .ExactInputSingleParams({
                    tokenIn: _arth,
                    tokenOut: _weth,
                    fee: fee,
                    recipient: me,
                    deadline: block.timestamp,
                    amountIn: arth.balanceOf(me),
                    amountOutMinimum: 1,
                    sqrtPriceLimitX96: 0
                });
            uniswapV3SwapRouter.exactInputSingle(params);
        }

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

    /// @dev in case admin needs to execute some calls directly
    function emergencyCall(address target, bytes memory signature) external payable onlyOwner {
        (bool success, bytes memory response) = target.call{value: msg.value}(signature);
        require(success, string(response));
    }
}
