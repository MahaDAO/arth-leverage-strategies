// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {console} from "hardhat/console.sol";
import {IStableSwap} from "../../interfaces/IStableSwap.sol";
import {IPriceFeed} from "../../interfaces/IPriceFeed.sol";

library ARTHUSDCCurveLogic {
    using SafeMath for uint256;

    event Deposit(address indexed src, uint256 wad);
    event Withdrawal(address indexed dst, uint256 wad);

    struct Position {
        uint64 depositedAt;
        uint64 lockDuration;
        uint256 totalUsdc;
        uint256 usdcSupplied;
        uint256 arthBorrowed;
        uint256 usdcInLp;
        uint256 lpTokensMinted;
    }

    struct DepositParams {
        address me;
        address treasury;
        IERC20 usdc;
        IERC20 arth;
        ILendingPool lendingPool;
        IStableSwap stableswap;
        IPriceFeed priceFeed;
    }

    function deposit(
        mapping(address => Position) storage positions,
        address who,
        uint256 usdcSupplied,
        uint256 minLiquidityReceived,
        uint64 lockDuration,
        DepositParams memory p
    ) external {
        console.log("in deposit");
        // 1. Check that position is not already open.
        require(positions[who].depositedAt == 0, "Position already open");

        // 2. Calculate usdc amount for pools.
        // LTV = 95% -> 51.282051% into lending
        uint256 usdcToLendingPool = usdcSupplied.mul(51282051).div(100000000); // 51% into lending
        uint256 usdcToLiquidityPool = usdcSupplied.sub(usdcToLendingPool);
        console.log("usdcToLendingPool", usdcToLendingPool);
        console.log("usdcToLiquidityPool", usdcToLiquidityPool);

        // 3. Supply usdc to the lending pool.
        p.lendingPool.supply(address(p.usdc), usdcToLendingPool, p.me, 0);
        console.log("usdc deposited in mahalend", usdcToLendingPool);

        // 4. Borrow ARTH at a 95% LTV
        uint256 arthToBorrow = usdcToLendingPool
            .mul(1e18 * 95 * 1e12)
            .div(p.priceFeed.fetchPrice())
            .div(100);

        console.log("borrowing arth", arthToBorrow);
        p.lendingPool.borrow(address(p.arth), arthToBorrow, 1, 0, p.me);
        console.log("borrowed arth", arthToBorrow);

        // 5. Supply to curve lp pool.
        console.log("supplying to curve");
        console.log("usdc", usdcToLiquidityPool);
        console.log("arth", arthToBorrow);
        uint256[2] memory inAmounts = [arthToBorrow, usdcToLiquidityPool];
        uint256 liquidityReceived = p.stableswap.add_liquidity(
            inAmounts,
            minLiquidityReceived,
            true
        );
        console.log("supplied to curve");

        // 6. Record the position.
        positions[who] = Position({
            depositedAt: uint64(block.timestamp),
            lockDuration: lockDuration,
            arthBorrowed: arthToBorrow,
            totalUsdc: usdcSupplied,
            usdcSupplied: usdcToLendingPool,
            usdcInLp: usdcToLiquidityPool,
            lpTokensMinted: liquidityReceived
        });

        emit Deposit(who, usdcSupplied);
    }

    function withdraw(
        mapping(address => Position) storage positions,
        address who,
        DepositParams memory p
    ) external {
        require(positions[who].depositedAt > 0, "Position not open");

        // 1. Remove the position and withdraw you stake for stopping further rewards.
        Position memory pos = positions[who];

        // 2. Withdraw liquidity from liquidity pool.
        // uint256[2] memory outAmounts = [uint256(0), uint256(0)];
        uint256[2] memory outAmounts = [pos.arthBorrowed, pos.usdcInLp];

        uint256 expectedLiquidityBurnt = p.stableswap.calc_token_amount(outAmounts);
        console.log("expectedLiquidityBurnt", expectedLiquidityBurnt);
        console.log("pos.lpTokensMinted", pos.lpTokensMinted);

        require(expectedLiquidityBurnt <= pos.lpTokensMinted, "Actual liq. < required");
        p.stableswap.remove_liquidity(expectedLiquidityBurnt, outAmounts);
        // require(amountsWithdrawn[0] >= pos.arthBorrowed, "not enough arth from lp");
        // require(amountsWithdrawn[1] >= pos.totalUsdc - pos.usdcSupplied, "not enough usdc from lp");

        // // Swap some usdc for arth in case arth from withdraw < arth required to repay.
        // if (arthWithdrawnFromLp < pos.arthBorrowed) {
        //     uint256 expectedOut = stableswap.get_dy(
        //         1,
        //         0,
        //         amountsWithdrawn[1]
        //     );
        //     uint256 out = stableswap.exchange(
        //         int128(uint128(_usdcLpCoinIndex)),
        //         int128(uint128(_arthLpCoinIndex)),
        //         amountsWithdrawn[0],
        //         expectedOut,
        //         _me
        //     );
        //     require(out >= expectedOut, "USDC to ARTH swap slippage");
        // }

        // 3. Repay arth borrowed from lending pool.
        console.log("usdc balance", p.usdc.balanceOf(p.me));
        console.log("arth balance", p.arth.balanceOf(p.me));
        p.lendingPool.repay(address(p.arth), pos.arthBorrowed, 1, p.me);

        // 4. Withdraw usdc supplied to lending pool.
        p.lendingPool.withdraw(address(p.usdc), pos.usdcSupplied, p.me);

        // Send the dust back to the sender
        p.usdc.transfer(who, pos.totalUsdc);
        emit Withdrawal(who, pos.totalUsdc);

        delete positions[who];
    }
}
