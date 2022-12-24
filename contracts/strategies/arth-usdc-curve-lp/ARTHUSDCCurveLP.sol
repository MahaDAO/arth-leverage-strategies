// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
import {StakingRewardsChild} from "../../staking/StakingRewardsChild.sol";
import {IPriceFeed} from "../../interfaces/IPriceFeed.sol";
import {Multicall} from "../../utils/Multicall.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {console} from "hardhat/console.sol";
import {IStableSwap} from "../../interfaces/IStableSwap.sol";

contract ARTHUSDCCurveLP is Initializable, StakingRewardsChild, Multicall {
    using SafeMath for uint256;

    event Deposit(address indexed src, uint256 wad);
    event Withdrawal(address indexed dst, uint256 wad);

    struct Position {
        bool isActive;
        uint256 arthBorrowed;
        uint256 usdcSupplied;
        uint256 usdcInLp;
        uint256 arthInLp;
        uint256 liquidity;
        uint256 totalUsdc;
        uint256 interestRateMode;
    }

    struct DepositParams {
        uint256 arthToBorrow;
        uint256 totalUsdcSupplied;
        uint256 minUsdcInLp;
        uint256 minArthInLp;
        uint256 minLiquidityReceived;
        uint16 lendingReferralCode;
        uint256 interestRateMode;
    }

    address private _me;
    address private _arth;
    address private _usdc;

    uint256 private _arthLpCoinIndex;
    uint256 private _usdcLpCoinIndex;

    mapping(address => Position) public positions;

    IERC20 public arth;
    IERC20 public usdc;
    ILendingPool public lendingPool;
    IStableSwap public liquidityPool;

    function initialize(
        address __usdc,
        address __arth,
        address __maha,
        address _lendingPool,
        address _liquidityPool,
        uint256 _rewardsDuration,
        address _operator,
        address _owner
    ) external initializer {
        arth = IERC20(__arth);
        usdc = IERC20(__usdc);
        lendingPool = ILendingPool(_lendingPool);
        liquidityPool = IStableSwap(_liquidityPool);

        _arth = __arth;
        _usdc = __usdc;
        _me = address(this);

        usdc.approve(_lendingPool, type(uint256).max);
        arth.approve(_lendingPool, type(uint256).max);
        usdc.approve(_liquidityPool, type(uint256).max);
        arth.approve(_liquidityPool, type(uint256).max);

        _arthLpCoinIndex = liquidityPool.coins(0) == _arth ? 0 : 1;
        _usdcLpCoinIndex = liquidityPool.coins(0) == _arth ? 1 : 0;

        _stakingRewardsChildInit(__maha, _rewardsDuration, _operator);
        _transferOwnership(_owner);
    }

    function deposit(DepositParams memory depositParams) external {
        _deposit(msg.sender, depositParams);
    }

    function withdraw() external payable {
        _withdraw(msg.sender);
    }

    function _deposit(address who, DepositParams memory depositParams) internal nonReentrant {
        // 1. Check that position is not already open.
        require(!positions[who].isActive, "Position already open");

        // 2. Pull usdc for lending pool and lp form the msg.sender.
        bool hasPulledUsdc = usdc.transferFrom(msg.sender, _me, depositParams.totalUsdcSupplied);
        require(hasPulledUsdc, "USDC pull failed");

        // 3. Calculate usdc amount for pools.
        uint256 _usdcToLendingPool = depositParams.totalUsdcSupplied.div(2);
        uint256 _usdcToLiquidityPool = depositParams.totalUsdcSupplied.sub(_usdcToLendingPool);

        // Supply usdc to the lending pool.
        uint256 usdcBeforeSupplying = usdc.balanceOf(_me);
        lendingPool.supply(
            _usdc,
            _usdcToLendingPool,
            _me, // On behalf of this contract.
            depositParams.lendingReferralCode
        );
        uint256 usdcAfterSupplying = usdc.balanceOf(_me);
        require(
            usdcBeforeSupplying.sub(usdcAfterSupplying) == _usdcToLendingPool,
            "Slippage while supplying USDC"
        );

        // Borrow ARTH.
        uint256 arthBeforeBorrowing = arth.balanceOf(_me);
        lendingPool.borrow(
            _arth,
            depositParams.arthToBorrow,
            depositParams.interestRateMode,
            depositParams.lendingReferralCode,
            _me
        );
        uint256 arthAfterBorrowing = arth.balanceOf(_me);
        uint256 arthBorrowed = arthAfterBorrowing.sub(arthBeforeBorrowing);
        require(arthBorrowed == depositParams.arthToBorrow, "Slippage while borrowing ARTH");

        // Supply to curve lp pool.
        uint256[] memory inAmounts = new uint256[](2);
        inAmounts[_arthLpCoinIndex] = arthBorrowed;
        inAmounts[_usdcLpCoinIndex] = _usdcToLiquidityPool;
        uint256 liquidityReceived = liquidityPool.add_liquidity(
            inAmounts,
            depositParams.minLiquidityReceived,
            false,
            _me
        );

        // Record the staking in the staking contract for maha rewards
        _stake(who, depositParams.totalUsdcSupplied);

        // Record the position.
        positions[who] = Position({
            isActive: true,
            arthBorrowed: arthBorrowed,
            usdcSupplied: _usdcToLendingPool,
            usdcInLp: _usdcToLiquidityPool,
            arthInLp: arthBorrowed,
            liquidity: liquidityReceived,
            totalUsdc: depositParams.totalUsdcSupplied,
            interestRateMode: depositParams.interestRateMode
        });

        // Send the dust back to the address that gave the funds.
        _flush(msg.sender);
        emit Deposit(who, depositParams.totalUsdcSupplied);
    }

    function _withdraw(address who) internal nonReentrant {
        require(positions[who].isActive, "Position not open");

        // 1. Remove the position and withdraw you stake for stopping further rewards.
        Position memory position = positions[who];
        _withdraw(who, position.totalUsdc);
        delete positions[who];

        // 2. Withdraw liquidity from liquidity pool.
        uint256[] memory outAmounts = new uint256[](2);
        outAmounts[_arthLpCoinIndex] = position.arthInLp;
        outAmounts[_usdcLpCoinIndex] = position.usdcInLp;
        uint256 expectedLiquidityBurnt = liquidityPool.calc_token_amount(outAmounts, false);
        require(expectedLiquidityBurnt <= position.liquidity, "Actual liq. < required");
        uint256[] memory amountsWithdrawn = liquidityPool.remove_liquidity(
            position.liquidity,
            outAmounts,
            false,
            _me
        );
        require(
            amountsWithdrawn[_arthLpCoinIndex] >= outAmounts[_arthLpCoinIndex],
            "Withdraw Slippage for coin 0"
        );
        require(
            amountsWithdrawn[_usdcLpCoinIndex] >= outAmounts[_usdcLpCoinIndex],
            "Withdraw Slippage for coin 1"
        );

        (uint256 arthWithdrawnFromLp, uint256 usdcWithdrawnFromLp) = (
            amountsWithdrawn[_arthLpCoinIndex],
            amountsWithdrawn[_usdcLpCoinIndex]
        );

        // Swap some usdc for arth in case arth from withdraw < arth required to repay.
        if (arthWithdrawnFromLp < position.arthBorrowed) {
            uint256 expectedOut = liquidityPool.get_dy(
                int128(uint128(_usdcLpCoinIndex)),
                int128(uint128(_arthLpCoinIndex)),
                usdcWithdrawnFromLp
            );
            uint256 out = liquidityPool.exchange(
                int128(uint128(_usdcLpCoinIndex)),
                int128(uint128(_arthLpCoinIndex)),
                usdcWithdrawnFromLp,
                expectedOut,
                _me
            );
            require(out >= expectedOut, "USDC to ARTH swap slippage");
        }

        // 3. Repay arth borrowed from lending pool.
        uint256 arthRepayed = lendingPool.repay(
            _arth,
            position.arthBorrowed,
            position.interestRateMode,
            _me
        );
        require(arthRepayed == position.arthBorrowed, "ARTH repay != borrowed");

        // 4. Withdraw usdc supplied to lending pool.
        uint256 usdcWithdrawn = lendingPool.withdraw(_usdc, position.usdcSupplied, _me);
        require(usdcWithdrawn >= position.usdcSupplied, "Slippage with withdrawing usdc");

        // Send the dust back to the sender
        _flush(who);
        emit Withdrawal(who, position.totalUsdc);
    }

    function _flush(address to) internal {
        uint256 arthBalance = arth.balanceOf(_me);
        if (arthBalance > 0) assert(arth.transfer(to, arthBalance));

        uint256 usdcBalance = usdc.balanceOf(_me);
        if (usdcBalance > 0) assert(usdc.transfer(to, usdcBalance));
    }

    function flush(address to) external {
        _flush(to);
    }

    function collectRewards() external nonReentrant {
        Position memory position = positions[msg.sender];
        require(position.isActive, "Position not open");
        _getReward();
    }

    /// @dev in case admin needs to execute some calls directly
    function emergencyCall(address target, bytes memory signature) external payable onlyOwner {
        (bool success, bytes memory response) = target.call{value: msg.value}(signature);
        require(success, string(response));
    }
}
