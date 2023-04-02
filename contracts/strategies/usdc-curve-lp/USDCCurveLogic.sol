// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILendingPool} from "../../interfaces/ILendingPool.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IStableSwap} from "../../interfaces/IStableSwap.sol";
import {IPriceFeed} from "../../interfaces/IPriceFeed.sol";

library USDCCurveLogic {
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
        IERC20 usdc;
        IERC20 arth;
        ILendingPool lendingPool;
        IStableSwap stableswap;
        IPriceFeed priceFeed;
    }

    struct WithdrawParams {
        address me;
        address treasury;
        IERC20 usdc;
        IERC20 arth;
        IERC20 lp;
        IERC20 varDebtArth;
        ILendingPool lendingPool;
        IStableSwap stableswap;
        uint256 totalUsdcSupplied;
        uint256 totalArthBorrowed;
    }

    function deposit(
        mapping(address => Position) storage positions,
        address _who,
        uint256 _totalUsdc,
        uint256 _minLiquidityReceived,
        uint64 _lockDuration,
        DepositParams memory _p
    ) external returns (uint256 arthBorrowed) {
        // 1. Check that position is not already open.
        require(positions[_who].depositedAt == 0, "position open");

        // 2. Calculate usdc amount for pools.
        // LTV = 95% -> 51.282051% into lending
        uint256 usdcToLendingPool = _totalUsdc.mul(51282051).div(100000000); // 51% into lending
        uint256 usdcToLiquidityPool = _totalUsdc.sub(usdcToLendingPool);

        // 3. Supply usdc to the lending pool.
        _p.lendingPool.supply(address(_p.usdc), usdcToLendingPool, _p.me, 0);

        // 4. Borrow ARTH at a 95% LTV
        arthBorrowed = usdcToLendingPool.mul(95e30).div(_p.priceFeed.fetchPrice()).div(100);
        _p.lendingPool.borrow(address(_p.arth), arthBorrowed, 2, 0, _p.me);

        // 5. Supply to curve lp pool.
        uint256[2] memory inAmounts = [arthBorrowed, usdcToLiquidityPool];
        uint256 lpTokensMinted = _p.stableswap.add_liquidity(inAmounts, _minLiquidityReceived);

        // 6. Record the position.
        positions[_who] = Position({
            depositedAt: uint64(block.timestamp),
            lockDuration: _lockDuration,
            arthBorrowed: arthBorrowed,
            totalUsdc: _totalUsdc,
            usdcSupplied: usdcToLendingPool,
            usdcInLp: usdcToLiquidityPool,
            lpTokensMinted: lpTokensMinted
        });

        emit Deposit(_who, _totalUsdc);
    }

    function withdraw(
        mapping(address => Position) storage positions,
        address who,
        WithdrawParams memory p
    ) external {
        require(positions[who].depositedAt > 0, "!position");

        // 1. Remove the position and withdraw you stake for stopping further rewards.
        Position memory pos = positions[who];

        // calculate interest to be paid first
        uint256 debt = p.varDebtArth.balanceOf(p.me) - p.totalArthBorrowed;
        uint256 debtOwed = (debt * pos.totalUsdc) / (p.totalUsdcSupplied);

        // 2. Withdraw liquidity from liquidity pool.
        uint256[2] memory outAmounts = [pos.arthBorrowed + debtOwed, pos.usdcInLp];
        uint256 expectedLiquidityBurnt = p.stableswap.calc_token_amount(outAmounts);

        // give a 3% slippage (given that ideally arth would be trading within a 3% range)
        p.stableswap.remove_liquidity(expectedLiquidityBurnt.mul(103).div(100), outAmounts);

        // 3. Repay arth borrowed with interest to the  lending pool.
        p.lendingPool.repay(address(p.arth), pos.arthBorrowed + debt, 2, p.me);

        // 4. Withdraw usdc supplied from the lending pool.
        p.lendingPool.withdraw(address(p.usdc), pos.usdcSupplied, p.me);

        // Send the usdc back to the user
        if (block.timestamp < pos.lockDuration + pos.depositedAt) {
            // charge a early withdrawal 100$ fee
            p.usdc.transfer(who, pos.totalUsdc.sub(100 * 1e6));
            p.usdc.transfer(p.treasury, 100 * 1e6);
        } else p.usdc.transfer(who, pos.totalUsdc);

        // send any dust back into curve
        uint256[2] memory inAmounts = [p.arth.balanceOf(p.me), p.usdc.balanceOf(p.me)];
        if (inAmounts[0] > 0 || inAmounts[1] > 0) p.stableswap.add_liquidity(inAmounts, 0);

        // send any balance LP back to the treasury; this is trading fees <3
        if (expectedLiquidityBurnt > pos.lpTokensMinted) {
            p.lp.transfer(p.treasury, expectedLiquidityBurnt - pos.lpTokensMinted);
        }

        emit Withdrawal(who, pos.totalUsdc);
        delete positions[who];
    }

    function minLiquidityReceived(
        uint256 totalUsdc,
        uint256 price,
        IStableSwap stableswap
    ) public view returns (uint256) {
        uint256 usdcToLendingPool = totalUsdc.mul(51282051).div(100000000); // 51% into lending
        uint256 usdcToLiquidityPool = totalUsdc.sub(usdcToLendingPool);

        uint256 arthBorrowed = usdcToLendingPool.mul(95e30).div(price).div(100);

        uint256[2] memory outAmounts = [arthBorrowed, usdcToLiquidityPool];
        return stableswap.calc_token_amount(outAmounts);
    }
}
