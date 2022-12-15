// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {IBorrowerOperations} from "../../interfaces/IBorrowerOperations.sol";
import {StakingRewardsChild} from "../artheth-trove-lp/StakingRewardsChild.sol";
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

        _stakingRewardsChildInit(__maha, _rewardsDuration, _operator);
        _transferOwnership(_owner);
    }

    function deposit(DepositParams memory depositParams) external {
        _deposit(msg.sender, depositParams);
    }

    // function withdraw(LoanParams memory loanParams) external payable {
    //     _withdraw(msg.sender, loanParams);
    // }

    function _deposit(address who, DepositParams memory depositParams) internal nonReentrant {
        // 1. Check that position is not already open.
        require(!positions[who].isActive, "Position already open");

        // 2. Pull usdc for lending pool and lp form the msg.sender.
        bool hasPulledUsdc = usdc.transferFrom(msg.sender, _me, depositParams.totalUsdcSupplied);
        require(hasPulledUsdc, "USDC pull failed");

        // 3. Calculate usdc amount for pools.
        uint256 _usdcToLendingPool = totalUsdcSupplied.div(2);
        uint256 _usdcToLiquidityPool = totalUsdcSupplied.sub(_usdcToLendingPool);

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
        uint25 arthBorrowed = arthAfterBorrowing.sub(arthBeforeBorrowing);
        require(arthBorrowed == depositParams.arthToBorrow, "Slippage while borrowing ARTH");

        // Supply to curve lp pool.
        uint256[] memory amounts = [];
        uint256 expectedLiquidity = liquidityPool.calc_token_amount(amounts, true);
        require(
            expectedLiquidity >= depositParams.minLiquidityReceived,
            "Expected liq. < desired liq."
        );
        uint256 liquidityReceived = liquidityPool.add_liquidity(amounts, expectedLiquidity);
        require(liquidityReceived >= expectedLiquidity, "Slippage while adding liq.");

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
            totalUsdc: depositParams.totalUsdcSupplied
        });

        // Send the dust back.
        _flush(who);
        emit Deposit(who, depositParams.totalUsdcSupplied);
    }

    // function _withdraw(address who, LoanParams memory loanParams) internal nonReentrant {
    //     require(positions[who].isActive, "Position not open");

    //     // 1. Remove the position and withdraw you stake for stopping further rewards.
    //     Position memory position = positions[who];
    //     _withdraw(who, position.ethForLoan);
    //     delete positions[who];

    //     // 2. Withdraw from the lending pool.
    //     uint256 arthWithdrawn = pool.withdraw(_arth, position.arthInLendingPool, me);

    //     // 3. Ensure that we received correct amount of arth to remove collateral from loan.
    //     require(arthWithdrawn >= position.arthFromLoan, "withdrawn is less");

    //     // 4. Adjust the trove, to remove collateral.
    //     borrowerOperations.adjustTrove(
    //         loanParams.maxFee,
    //         position.ethForLoan,
    //         arthWithdrawn,
    //         false,
    //         loanParams.upperHint,
    //         loanParams.lowerHint
    //     );

    //     // Send the dust back to the sender
    //     _flush(who);
    //     emit Withdrawal(who, position.ethForLoan);
    // }

    function _flush(address to) internal {
        uint256 arthBalance = arth.balanceOf(_me);
        if (arthBalance > 0) assert(arth.transfer(to, arthBalance));

        uint256 usdcBalance = usdc.balanceOf(_me);
        if (usdcBalance > 0) assert(usdc.transfer(to, arthBalance));
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
