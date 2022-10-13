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

contract ARTHETHTroveLP is StakingRewardsChild, MerkleWhitelist {
    using SafeMath for uint256;

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    struct Position {
        uint256 ethInLoan;
        uint256 arthFromLoan;
        uint256 openLoanBlkNumber;
        uint256 ethInLp;
        uint256 arthInLp;
        uint256 lpTokenId;
        uint256 liquidityInLp;
        uint256 liqProvideBlkNumber;
    }

    bool public isARTHToken0;
    uint24 public fee;
    uint256 public minCollateralRatio = 3 * 1e18; // 300% CR
    address private me;
    address private _arth;
    address private _weth;

    mapping(address => Position) public positions;

    IERC20 public arth;
    IERC20 public weth;
    IPriceFeed public priceFeed;
    IBorrowerOperations public borrowerOperations;
    IUniswapV3SwapRouter public uniswapV3SwapRouter;
    INonfungiblePositionManager public uniswapNFTManager;

    constructor(
        address _borrowerOperations,
        address _uniswapNFTManager,
        address __arth,
        address __maha,
        address __weth,
        uint24 _fee,
        address _uniswapV3SwapRouter,
        address _priceFeed,
        bool _isARTHToken0
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

        arth.approve(_uniswapNFTManager, type(uint256).max);

        isARTHToken0 = _isARTHToken0;
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
        _flush(owner(), false, 0);
    }

    /// @notice admin-only function to close the trove; normally not needed if the campaign keeps on running
    function closeTrove(uint256 arthNeeded) external payable onlyOwner nonReentrant {
        // Get the ARTH needed to close the loan.
        arth.transferFrom(msg.sender, me, arthNeeded);

        // Close the trove.
        borrowerOperations.closeTrove();

        // Return dust ARTH, ETH.
        _flush(owner(), false, 0);
    }

    function depositInTrove(
        uint256 maxFee,
        address upperHint,
        address lowerHint,
        uint256 arthAmount,
        uint256 rootId,
        bytes32[] proof
    ) public payable checkWhitelist(msg.sender, rootId, proof) nonReentrant {
        Position memory position = positions[msg.sender];
        // Check that position is not already open.
        require(position.openLoanBlkNumber == 0, "Position loan already open");
        require(position.liqProvideBlkNumber == 0, "Position lp already provided");

        // The collateral ratio should be > minCollateralRatio.
        uint256 price = priceFeed.fetchPrice();
        uint256 currenctCollateralRatio = price.mul(msg.value).div(arthAmount);
        require(currenctCollateralRatio >= mintCollateralRatio, "CR must be > 299%");

        // Mint ARTH and track ARTH balance changes due to this current tx.
        borrowerOperations.adjustTrove{value: msg.value}(
            maxFee,
            0, // No coll withdrawal.
            arthAmount, // Mint ARTH.
            true, // Debt increasing.
            upperHint,
            lowerHint
        );

        // Record the status of position in troves.
        position.ethInLoan = msg.value;
        positoin.arthFromLoan = arthAmount;
        position.openLoanBlkNumber = block.number;
        positions[msg.sender] = position;

        // Record staking for MAHA rewards.
        _stake(msg.sender, position.ethInLoan);

        // Refund any dust left.
        _flush(msg.sender, false, 0);

        // TODO: update events.
        emit Deposit(msg.sender, msg.value);
    }

    function depositInLp(
        INonfungiblePositionManager.MintParams memory lpMintParams,
        uint256 rootId,
        bytes32[] proof
    ) public payable checkWhitelist(msg.sender, rootId, proof) nonReentrant {
        Position memory position = positions[msg.sender];
        // Check that position is not already open.
        require(position.openLoanBlkNumber != 0, "Position loan not open");
        require(position.liqProvideBlkNumber == 0, "Position liqudity already provided");
        
        // Check that the block is the same as the one in which we depositedInLoans
        require(block.number == position.openLoanBlkNumber, "Block diff > 0");

        // Provide liquidity in the lp.
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = uniswapNFTManager
            .mint{value: uniswapPoisitionMintParams.ethAmountDesired}(lpMintParams);

        // Record the status of position in lp pool.
        position.liqProvideBlkNumber = block.number;
        position.arthInLp = isARTHToken0 ? amount0 : amount1;
        position.ethInLp = isARTHToken0 ? amoun1 : amount0; 
        position.liquidityInLp = liquidity;
        position.lpTokenId = tokenId;
        positions[msg.sender] = position;

        // Update staking for MAHA rewards.
        _stake(msg.sender, position.ethInLp);
        
        // Refund any dust left.
        _flush(msg.sender, false, 0);

        // TODO: update events.
        emit Deposit(msg.sender, msg.value);
    }

    function withdrawFromLp(
        INonfungiblePositionManager memory lpDecreaseParams
    ) public payable nonReentrant {
        Position memory position = positions[msg.sender];

        require(position.openLoanBlkNumber != 0, "Position loan not open");
        require(position.lpTokenId != 0, "Position liquidity not provided");
        require(position.liqProvideBlkNumber != 0, "Position liquidity not provided");
        
        // Claim the rewards.
        _getReward();
        // Claim the LP fees.
        _collectFees(position.lpTokenId);

        // Decrease the MAHA staking.
        _withdraw(msg.sender, position.ethInLp);
        
        require(lpDecreaseParams.tokenId == position.lpTokenId, "Lp Token Id not same");
        (uint256 amount0, uint256 amount1) = uniswapNFTManager.decreaseLiquidity(lpDecreaseParams);

        // 4. Check if the ARTH we received is less.
        if (arthAmountOut < position.debt) {
            // Then we swap the ETH for remaining ARTH in the ARTH/ETH pool.
            uint256 arthNeeded = position.debt.sub(arthAmountOut);
            IUniswapV3SwapRouter.ExactOutputSingleParams memory params = IUniswapV3SwapRouter
                .ExactOutputSingleParams({
                    tokenIn: _weth,
                    tokenOut: _arth,
                    fee: fee,
                    recipient: me,
                    deadline: block.timestamp,
                    amountOut: arthNeeded,
                    amountInMaximum: amountETHswapMaximum,
                    sqrtPriceLimitX96: 0
                });
            uint256 ethUsed = uniswapV3SwapRouter.exactOutputSingle{value: amountETHswapMaximum}(params);
            ethAmountOut = ethAmountOut.sub(ethUsed); // Decrease the amount of ETH we have, since we swapped it for ARTH.
        }
      
        // 6. Flush, send back the amount received with dust.
        _flush(msg.sender, true, ethOutMin);
        
        emit Withdrawal(msg.sender, position.eth);
    }

    function _flush(address to, bool shouldSwapARTHForETH, uint256 amountOutMin) internal {
        if (shouldSwapARTHForETH) {
            IUniswapV3SwapRouter.ExactInputSingleParams memory params = IUniswapV3SwapRouter
                .ExactInputSingleParams({
                    tokenIn: _arth,
                    tokenOut: _weth,
                    fee: fee,
                    recipient: me,
                    deadline: block.timestamp,
                    amountIn: arth.balanceOf(me),
                    amountOutMinimum: amountOutMin,
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

    function collectRewards() external payable nonReentrant {
        Position memory position = positions[msg.sender];
        require(position.lpTokenId != 0, "Position not open");
        _getReward();
        _collectFees(position.uniswapNftId);
    }

    function _collectFees(uint256 lpTokenId) internal {
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager
            .CollectParams({
                recipient: me,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max,
                tokenId: lpTokenId
            });

        // Trigger the fee collection for the nft owner.
        uniswapNFTManager.collect(params);
    }

    /// @dev in case admin needs to execute some calls directly
    function emergencyCall(address target, bytes memory signature) external payable onlyOwner {
        (bool success, bytes memory response) = target.call{value: msg.value}(signature);
        require(success, string(response));
    }
}
