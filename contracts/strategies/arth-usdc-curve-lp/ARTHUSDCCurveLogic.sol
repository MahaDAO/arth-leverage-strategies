// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {console} from "hardhat/console.sol";
import {IStableSwap} from "../../interfaces/IStableSwap.sol";

library ARTHUSDCCurveLogic {
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

    struct DepositInputParams {
        uint256 arthToBorrow;
        uint256 totalUsdcSupplied;
        uint256 minUsdcInLp;
        uint256 minArthInLp;
        uint256 minLiquidityReceived;
        uint256 interestRateMode;
    }

    struct DepositParams {
        address me;
        address treasury;
        uint8 arthLpCoinIndex;
        uint8 usdcLpCoinIndex;
        IERC20 usdc;
        IERC20 arth;
        ILendingPool lendingPool;
        IStableSwap stableswap;
    }

    function deposit(
        mapping(address => Position) storage positions,
        address who,
        DepositInputParams memory i,
        DepositParams memory p
    ) external {
        console.log("in deposit");
        // 1. Check that position is not already open.
        require(!positions[who].isActive, "Position already open");

        // 3. Calculate usdc amount for pools.
        uint256 _usdcToLendingPool = i.totalUsdcSupplied.div(2);
        uint256 _usdcToLiquidityPool = i.totalUsdcSupplied.sub(_usdcToLendingPool);

        // Supply usdc to the lending pool.
        p.lendingPool.supply(address(p.usdc), _usdcToLendingPool, p.me, 0);
        console.log("usdc deposited in mahalend", _usdcToLendingPool);

        // Borrow ARTH.
        p.lendingPool.borrow(address(p.arth), i.arthToBorrow, i.interestRateMode, 0, p.me);

        // Supply to curve lp pool.
        uint256[] memory inAmounts = new uint256[](2);
        inAmounts[p.arthLpCoinIndex] = i.arthToBorrow;
        inAmounts[p.usdcLpCoinIndex] = _usdcToLiquidityPool;
        uint256 liquidityReceived = p.stableswap.add_liquidity(
            inAmounts,
            i.minLiquidityReceived,
            false,
            p.me
        );

        // Record the position.
        positions[who] = Position({
            isActive: true,
            arthBorrowed: i.arthToBorrow,
            usdcSupplied: _usdcToLendingPool,
            usdcInLp: _usdcToLiquidityPool,
            arthInLp: i.arthToBorrow,
            liquidity: liquidityReceived,
            totalUsdc: i.totalUsdcSupplied,
            interestRateMode: i.interestRateMode
        });

        emit Deposit(who, i.totalUsdcSupplied);
    }

    // function withdraw(address who) external {
    //     require(positions[who].isActive, "Position not open");

    //     // 1. Remove the position and withdraw you stake for stopping further rewards.
    //     Position memory position = positions[who];
    //     _withdraw(who, position.totalUsdc);
    //     delete positions[who];

    //     // 2. Withdraw liquidity from liquidity pool.
    //     uint256[] memory outAmounts = new uint256[](2);
    //     outAmounts[_arthLpCoinIndex] = position.arthInLp;
    //     outAmounts[_usdcLpCoinIndex] = position.usdcInLp;
    //     uint256 expectedLiquidityBurnt = stableswap.calc_token_amount(outAmounts, false);
    //     require(expectedLiquidityBurnt <= position.liquidity, "Actual liq. < required");
    //     uint256[] memory amountsWithdrawn = stableswap.remove_liquidity(
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
    //         uint256 expectedOut = stableswap.get_dy(
    //             int128(uint128(_usdcLpCoinIndex)),
    //             int128(uint128(_arthLpCoinIndex)),
    //             usdcWithdrawnFromLp
    //         );
    //         uint256 out = stableswap.exchange(
    //             int128(uint128(_usdcLpCoinIndex)),
    //             int128(uint128(_arthLpCoinIndex)),
    //             usdcWithdrawnFromLp,
    //             expectedOut,
    //             _me
    //         );
    //         require(out >= expectedOut, "USDC to ARTH swap slippage");
    //     }

    //     // 3. Repay arth borrowed from lending pool.
    //     uint256 arthRepayed = lendingPool.repay(
    //         _arth,
    //         position.arthBorrowed,
    //         position.interestRateMode,
    //         _me
    //     );
    //     require(arthRepayed == position.arthBorrowed, "ARTH repay != borrowed");

    //     // 4. Withdraw usdc supplied to lending pool.
    //     uint256 usdcWithdrawn = lendingPool.withdraw(_usdc, position.usdcSupplied, _me);
    //     require(usdcWithdrawn >= position.usdcSupplied, "Slippage with withdrawing usdc");

    //     // Send the dust back to the sender
    //     _flush(who);
    //     emit Withdrawal(who, position.totalUsdc);
    // }

    // function _flush(address to) internal {
    //     uint256 arthBalance = arth.balanceOf(_me);
    //     if (arthBalance > 0) assert(arth.transfer(to, arthBalance));

    //     uint256 usdcBalance = usdc.balanceOf(_me);
    //     if (usdcBalance > 0) assert(usdc.transfer(to, usdcBalance));
    // }
}
