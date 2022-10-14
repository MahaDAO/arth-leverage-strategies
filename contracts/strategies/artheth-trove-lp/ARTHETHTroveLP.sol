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
import {Multicall} from "../../Multicall.sol";

contract ARTHETHTroveLP is StakingRewardsChild, MerkleWhitelist, Multicall {
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

    struct TroveParams {
        uint256 maxFee;
        address upperHint;
        address lowerHint;
    }

    struct WhitelistParams {
        uint256 rootId;
        bytes32[] proof;
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
        _flush(owner());
    }

    /// @notice admin-only function to close the trove; normally not needed if the campaign keeps on running
    function closeTrove(uint256 arthNeeded) external payable onlyOwner nonReentrant {
        // Get the ARTH needed to close the loan.
        arth.transferFrom(msg.sender, me, arthNeeded);

        // Close the trove.
        borrowerOperations.closeTrove();

        // Return dust ARTH, ETH.
        _flush(owner());
    }

    function depositInTrove(
        TroveParams memory troveParams,
        uint256 arthAmount,
        WhitelistParams memory whitelistParams
    ) public payable checkWhitelist(msg.sender, whitelistParams.rootId, whitelistParams.proof) nonReentrant {
        Position memory position = positions[msg.sender];
        // Check that position is not already open.
        require(position.openLoanBlkNumber == 0, "Position loan already open");
        require(position.liqProvideBlkNumber == 0, "Position lp already provided");

        // The collateral ratio should be > minCollateralRatio.
        require(
            priceFeed.fetchPrice().mul(msg.value).div(arthAmount) >= minCollateralRatio, 
            "CR must be > 299%"
        );

        // Mint ARTH and track ARTH balance changes due to this current tx.
        borrowerOperations.adjustTrove{value: msg.value}(
            troveParams.maxFee,
            0, // No coll withdrawal.
            arthAmount, // Mint ARTH.
            true, // Debt increasing.
            troveParams.upperHint,
            troveParams.lowerHint
        );

        // Record the status of position in troves.
        position.ethInLoan = msg.value;
        position.arthFromLoan = arthAmount;
        position.openLoanBlkNumber = block.number;
        positions[msg.sender] = position;

        // Record staking for MAHA rewards.
        _stake(msg.sender, position.ethInLoan);

        // Refund any dust left.
        _flush(msg.sender);

        // TODO: update events.
        emit Deposit(msg.sender, msg.value);
    }

    function depositInLp(
        INonfungiblePositionManager.MintParams memory lpMintParams,
        WhitelistParams memory whitelistParams
    ) public payable checkWhitelist(msg.sender, whitelistParams.rootId, whitelistParams.proof) nonReentrant {
        Position memory position = positions[msg.sender];
        // Check that position is not already open.
        require(position.openLoanBlkNumber != 0, "Position loan not open");
        require(position.liqProvideBlkNumber == 0, "Position liqudity already provided");
        
        // Check that the block is the same as the one in which we depositedInLoans
        require(block.number == position.openLoanBlkNumber, "Block diff > 0");

        // Provide liquidity in the lp.
        uint256 ethAmountDesired = isARTHToken0 ? lpMintParams.amount1Desired : lpMintParams.amount0Desired;
        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = uniswapNFTManager
            .mint{value: ethAmountDesired}(lpMintParams);

        // Record the status of position in lp pool.
        position.liqProvideBlkNumber = block.number;
        position.arthInLp = isARTHToken0 ? amount0 : amount1;
        position.ethInLp = isARTHToken0 ? amount1 : amount0; 
        position.liquidityInLp = liquidity;
        position.lpTokenId = tokenId;
        positions[msg.sender] = position;

        // Update staking for MAHA rewards.
        _stake(msg.sender, position.ethInLp);
        
        // Refund any dust left.
        _flush(msg.sender);

        require(
            positions[msg.sender].openLoanBlkNumber == positions[msg.sender].liqProvideBlkNumber,
            "Block diff >0"
        );

        // TODO: update events.
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(
        TroveParams memory troveParams,
        uint256 amountETHswapMaximum,
        INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseLiquidityParams,
        INonfungiblePositionManager.CollectParams memory collectFeesparams
    ) public payable nonReentrant {
        Position memory position = positions[msg.sender];
        
        require(position.lpTokenId != 0, "Position not open");
        require(position.openLoanBlkNumber != 0, "Position loan not open");
        require(position.liqProvideBlkNumber != 0, "Position lp not added");
        require(position.liqProvideBlkNumber == position.openLoanBlkNumber, "Block diff > 0");

        // Remove the position and withdraw your stake 
        // for stopping further rewards.
        _withdraw(msg.sender, position.ethInLoan.add(position.ethInLp));
        delete positions[msg.sender];

        // 2. Claim rewards & fees.
        _getReward();
        require(collectFeesparams.recipient == me, "invalid fee receiver");
        // Trigger the fee collection for the nft owner.
        uniswapNFTManager.collect(collectFeesparams);

        // 3. Remove the LP for ARTH/ETH.
        require(decreaseLiquidityParams.tokenId == position.lpTokenId, "Token id not same");
        require(decreaseLiquidityParams.liquidity == position.liquidityInLp, "Liquidity not same");
        (uint256 amount0, uint256 amount1) = uniswapNFTManager.decreaseLiquidity(decreaseLiquidityParams);
        uint256 ethAmountOut = isARTHToken0 ? amount0 : amount1;
        uint256 arthAmountOut = isARTHToken0 ? amount1 : amount0;

        // 4. Check if the ARTH we received is less.
        if (arthAmountOut < position.arthFromLoan) {
            // Then we swap the ETH for remaining ARTH in the ARTH/ETH pool.
            uint256 arthNeeded = position.arthFromLoan.sub(arthAmountOut);
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
       
        // 5. Adjust the trove, to remove collateral.
        borrowerOperations.adjustTrove(
            troveParams.maxFee,
            position.ethInLoan,
            position.arthFromLoan,
            false,
            troveParams.upperHint,
            troveParams.lowerHint
        );
      
        // 6. Flush, send back the amount received with dust.
        _flush(msg.sender);
        
        emit Withdrawal(msg.sender, position.ethInLoan.add(position.ethInLp));
    }

    function _flush(address to) internal {
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

    /// @dev in case admin needs to execute some calls directly
    function emergencyCall(address target, bytes memory signature) external payable onlyOwner {
        (bool success, bytes memory response) = target.call{value: msg.value}(signature);
        require(success, string(response));
    }
}
