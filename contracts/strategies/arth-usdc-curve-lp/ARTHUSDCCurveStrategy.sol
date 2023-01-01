// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VersionedInitializable} from "../../proxy/VersionedInitializable.sol";

import {StakingRewardsChild} from "../../staking/StakingRewardsChild.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {IStableSwap} from "../../interfaces/IStableSwap.sol";

import {ARTHUSDCCurveLogic} from "./ARTHUSDCCurveLogic.sol";

contract ARTHUSDCCurveLP is VersionedInitializable, StakingRewardsChild {
    event Deposit(address indexed src, uint256 wad);
    event Withdrawal(address indexed dst, uint256 wad);

    address private _me;
    uint8 private _arthLpCoinIndex;
    uint8 private _usdcLpCoinIndex;

    mapping(address => ARTHUSDCCurveLogic.Position) public positions;

    IERC20 public arth;
    IERC20 public usdc;
    ILendingPool public lendingPool;
    IStableSwap public liquidityPool;

    /// @notice all revenue gets sent over here.
    address public treasury;

    function initialize(
        address _usdc,
        address _arth,
        address _maha,
        address _lendingPool,
        address _liquidityPool,
        uint256 _rewardsDuration,
        address _operator,
        address _treasury,
        address _owner
    ) external initializer {
        arth = IERC20(_arth);
        usdc = IERC20(_usdc);
        lendingPool = ILendingPool(_lendingPool);
        liquidityPool = IStableSwap(_liquidityPool);

        treasury = _treasury;
        _me = address(this);

        usdc.approve(_lendingPool, type(uint256).max);
        arth.approve(_lendingPool, type(uint256).max);
        usdc.approve(_liquidityPool, type(uint256).max);
        arth.approve(_liquidityPool, type(uint256).max);

        _arthLpCoinIndex = liquidityPool.coins(0) == _arth ? 0 : 1;
        _usdcLpCoinIndex = liquidityPool.coins(0) == _arth ? 1 : 0;

        _stakingRewardsChildInit(_maha, _rewardsDuration, _operator);
        _transferOwnership(_owner);
    }

    function deposit(ARTHUSDCCurveLogic.DepositInputParams memory p) external {
        _deposit(msg.sender, p);
    }

    function depositWithPermit(
        address who,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        ARTHUSDCCurveLogic.DepositInputParams memory p
    ) external {
        IERC20Permit(address(usdc)).permit(who, _me, value, deadline, v, r, s);
        _deposit(who, p);
    }

    function _deposit(address who, ARTHUSDCCurveLogic.DepositInputParams memory p)
        internal
        nonReentrant
    {
        usdc.transferFrom(who, _me, p.totalUsdcSupplied);

        ARTHUSDCCurveLogic.deposit(
            positions,
            who,
            p,
            ARTHUSDCCurveLogic.DepositParams({
                me: _me, // address me;
                treasury: treasury, // address treasury;
                arthLpCoinIndex: _arthLpCoinIndex, // uint256 arthLpCoinIndex;
                usdcLpCoinIndex: _usdcLpCoinIndex, // uint256 usdcLpCoinIndex;
                usdc: usdc, // IERC20 usdc;
                arth: arth, // IERC20 arth;
                lendingPool: lendingPool, // ILendingPool lendingPool;
                stableswap: liquidityPool // IStableSwap stableswap;
            })
        );

        // Record the staking in the staking contract for maha rewards
        _stake(who, p.totalUsdcSupplied);

        // // Send the dust back to the address that gave the funds.
        // _flush(who);
    }

    // function withdraw() external payable {
    //     _withdraw(msg.sender);
    // }

    // function _withdraw(address who) internal nonReentrant {
    //     require(positions[who].isActive, "Position not open");

    //     // 1. Remove the position and withdraw you stake for stopping further rewards.
    //     Position memory position = positions[who];
    //     _withdraw(who, position.totalUsdc);
    //     delete positions[who];

    //     // 2. Withdraw liquidity from liquidity pool.
    //     uint256[] memory outAmounts = new uint256[](2);
    //     outAmounts[_arthLpCoinIndex] = position.arthInLp;
    //     outAmounts[_usdcLpCoinIndex] = position.usdcInLp;
    //     uint256 expectedLiquidityBurnt = liquidityPool.calc_token_amount(outAmounts, false);
    //     require(expectedLiquidityBurnt <= position.liquidity, "Actual liq. < required");
    //     uint256[] memory amountsWithdrawn = liquidityPool.remove_liquidity(
    //         position.liquidity,
    //         outAmounts,
    //         false,
    //         _me
    //     );
    //     require(
    //         amountsWithdrawn[_arthLpCoinIndex] >= outAmounts[_arthLpCoinIndex],
    //         "Withdraw Slippage for coin 0"
    //     );
    //     require(
    //         amountsWithdrawn[_usdcLpCoinIndex] >= outAmounts[_usdcLpCoinIndex],
    //         "Withdraw Slippage for coin 1"
    //     );

    //     (uint256 arthWithdrawnFromLp, uint256 usdcWithdrawnFromLp) = (
    //         amountsWithdrawn[_arthLpCoinIndex],
    //         amountsWithdrawn[_usdcLpCoinIndex]
    //     );

    //     // Swap some usdc for arth in case arth from withdraw < arth required to repay.
    //     if (arthWithdrawnFromLp < position.arthBorrowed) {
    //         uint256 expectedOut = liquidityPool.get_dy(
    //             int128(uint128(_usdcLpCoinIndex)),
    //             int128(uint128(_arthLpCoinIndex)),
    //             usdcWithdrawnFromLp
    //         );
    //         uint256 out = liquidityPool.exchange(
    //             int128(uint128(_usdcLpCoinIndex)),
    //             int128(uint128(_arthLpCoinIndex)),
    //             usdcWithdrawnFromLp,
    //             expectedOut,
    //             _me
    //         );
    //         require(out >= expectedOut, "USDC to ARTH swap slippage");
    //     }

    //     // 3. Repay arth borrowed from lending pool.
    //     require(
    //         lendingPool.repay(_arth, position.arthBorrowed, position.interestRateMode, _me) ==
    //             position.arthBorrowed,
    //         "ARTH repay != borrowed"
    //     );

    //     // 4. Withdraw usdc supplied to lending pool.
    //     uint256 usdcWithdrawn = lendingPool.withdraw(_usdc, position.usdcSupplied, _me);
    //     require(usdcWithdrawn >= position.usdcSupplied, "Slippage with withdrawing usdc");

    //     // Send the dust back to the sender
    //     _flush(who);
    //     emit Withdrawal(who, position.totalUsdc);
    // }

    function _flush(address to) internal {
        uint256 arthBalance = arth.balanceOf(_me);
        if (arthBalance > 0) assert(arth.transfer(to, arthBalance));

        uint256 usdcBalance = usdc.balanceOf(_me);
        if (usdcBalance > 0) assert(usdc.transfer(to, usdcBalance));
    }

    function flush(address to) external {
        _flush(to);
    }

    /// @dev in case admin needs to execute some calls directly
    function emergencyCall(address target, bytes memory signature) external payable onlyOwner {
        (bool success, bytes memory response) = target.call{value: msg.value}(signature);
        require(success, string(response));
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 0;
    }
}
