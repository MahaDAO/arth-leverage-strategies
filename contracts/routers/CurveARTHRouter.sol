// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20, IERC20WithDecimals} from "../interfaces/IERC20WithDecimals.sol";
import {IZapDepositor} from "../interfaces/IZapDepositor.sol";
import {IStableSwap} from "../interfaces/IStableSwap.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IStableSwapRouter} from "../interfaces/IStableSwapRouter.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract CurveARTHRouter is IStableSwapRouter {
    using SafeMath for uint256;

    IERC20WithDecimals public lp;
    IZapDepositor public zap;
    address public pool;

    IERC20Wrapper public arthUsd;
    IERC20WithDecimals public arth;
    IERC20WithDecimals public usdc;
    IERC20WithDecimals public usdt;
    IERC20WithDecimals public dai;

    address private me;

    constructor(
        address _zap,
        address _lp,
        address _pool,
        address _arth,
        address _arthUsd,
        address _usdc,
        address _usdt,
        address _dai
    ) {
        pool = _pool;

        arthUsd = IERC20Wrapper(_arthUsd);
        zap = IZapDepositor(_zap);

        lp = IERC20WithDecimals(_lp);
        arth = IERC20WithDecimals(_arth);
        usdc = IERC20WithDecimals(_usdc);
        usdt = IERC20WithDecimals(_usdt);
        dai = IERC20WithDecimals(_dai);

        me = address(this);
    }

    function sellARTHForExact(
        uint256 amountArthInMax,
        uint256 amountDAIOut,
        uint256 amountUSDCOut,
        uint256 amountUSDTOut,
        address to,
        uint256 deadline
    ) external override {
        // convert arth -> arth.usd
        arth.transferFrom(msg.sender, me, amountArthInMax);
        arth.approve(address(arthUsd), amountArthInMax);
        arthUsd.deposit(amountArthInMax);

        arthUsd.approve(address(zap), arthUsd.balanceOf(me));
        uint256[4] memory amountsIn = [arthUsd.balanceOf(me), 0, 0, 0];
        _addLiquidity(amountsIn, 0);

        lp.approve(address(zap), lp.balanceOf(me));

        if (amountDAIOut > 0) {
            uint256[4] memory amountsOut = [0, amountDAIOut, 0, 0];
            uint256 burnAmount = zap.calc_token_amount(pool, amountsOut, false);
            _removeLiquidityOneCoin(burnAmount.mul(101).div(100), 1, amountDAIOut);
        }

        if (amountUSDCOut > 0) {
            uint256[4] memory amountsOut = [0, 0, amountUSDCOut, 0];
            uint256 burnAmount = zap.calc_token_amount(pool, amountsOut, false);
            _removeLiquidityOneCoin(burnAmount.mul(101).div(100), 2, amountUSDCOut);
        }

        if (amountUSDTOut > 0) {
            uint256[4] memory amountsOut = [0, 0, 0, amountUSDTOut];
            uint256 burnAmount = zap.calc_token_amount(pool, amountsOut, false);
            _removeLiquidityOneCoin(burnAmount.mul(101).div(100), 3, amountUSDTOut);
        }

        // if there are some leftover lp tokens we extract it out as arth and send it back
        if (lp.balanceOf(me) > 1e12) _removeLiquidityOneCoin(lp.balanceOf(me), 0, 0);

        require(dai.balanceOf(me) >= amountDAIOut, "not enough dai out");
        require(usdc.balanceOf(me) >= amountUSDCOut, "not enough usdc out");
        require(usdt.balanceOf(me) >= amountUSDTOut, "not enough usdt out");
        require(block.timestamp <= deadline, "swap deadline expired");

        _flush(to);
    }

    function buyARTHForExact(
        uint256 amountDAIIn,
        uint256 amountUSDCIn,
        uint256 amountUSDTIn,
        uint256 amountARTHOutMin,
        address to,
        uint256 deadline
    ) external override {
        if (amountDAIIn > 0) dai.transferFrom(msg.sender, me, amountDAIIn);
        if (amountUSDCIn > 0) usdc.transferFrom(msg.sender, me, amountUSDCIn);
        if (amountUSDTIn > 0) usdt.transferFrom(msg.sender, me, amountUSDTIn);

        dai.approve(address(zap), amountDAIIn);
        usdc.approve(address(zap), amountUSDCIn);
        usdt.approve(address(zap), amountUSDTIn);

        uint256[4] memory amountsIn = [0, amountDAIIn, amountUSDCIn, amountUSDTIn];
        _addLiquidity(amountsIn, 0);

        lp.approve(address(zap), lp.balanceOf(me));
        uint256[4] memory amountsOut = [amountARTHOutMin.mul(2), 0, 0, 0];
        uint256 burnAmount = zap.calc_token_amount(pool, amountsOut, false);

        // todo make this revert properly
        _removeLiquidityOneCoin(burnAmount.mul(101).div(100), 0, amountARTHOutMin.mul(2));

        // if there are some leftover lp tokens we extract it out as arth and send it back
        if (lp.balanceOf(me) > 1e12) _removeLiquidityOneCoin(lp.balanceOf(me), 0, 0);

        arthUsd.withdraw(arthUsd.balanceOf(me).div(2));
        require(arth.balanceOf(me) >= amountARTHOutMin, "not enough arth out");
        require(block.timestamp <= deadline, "swap deadline expired");

        _flush(to);
    }

    function sellARTHforToken(
        int128 tokenId, // 1 -> dai, 2 -> usdc, 3 -> usdt
        uint256 amountARTHin,
        address to,
        uint256 deadline
    ) external override {
        if (amountARTHin > 0) arth.transferFrom(msg.sender, me, amountARTHin);
        arth.approve(address(arthUsd), amountARTHin);
        arthUsd.deposit(amountARTHin);

        arthUsd.approve(pool, arthUsd.balanceOf(me));
        IStableSwap swap = IStableSwap(pool);

        uint256 amountTokenOut = swap.get_dy_underlying(0, tokenId, amountARTHin);
        swap.exchange_underlying(0, tokenId, arthUsd.balanceOf(me), amountTokenOut, to);

        require(block.timestamp <= deadline, "swap deadline expired");

        _flush(to);
    }

    function sellTokenForToken(
        IERC20 fromToken,
        int128 fromTokenId, // 1 -> dai, 2 -> usdc, 3 -> usdt
        int128 toTokenId, // 1 -> dai, 2 -> usdc, 3 -> usdt
        uint256 amountInMax,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external override {
        if (amountInMax > 0) fromToken.transferFrom(msg.sender, me, amountInMax);

        fromToken.approve(pool, fromToken.balanceOf(me));
        IStableSwap swap = IStableSwap(pool);

        uint256 amountTokenOut = swap.get_dy_underlying(fromTokenId, toTokenId, amountInMax);
        require(amountTokenOut >= amountOutMin, "amountOutMin not met");

        swap.exchange_underlying(fromTokenId, toTokenId, amountInMax, amountTokenOut, to);
        require(block.timestamp <= deadline, "swap deadline expired");

        _flush(to);
    }

    function estimateARTHtoSell(
        uint256 daiNeeded,
        uint256 usdcNeeded,
        uint256 usdtNeeded
    ) external view override returns (uint256) {
        uint256[4] memory amountsIn = [0, daiNeeded, usdcNeeded, usdtNeeded];

        uint256 lpIn = zap.calc_token_amount(pool, amountsIn, false);
        uint256 arthUsdOut = zap.calc_withdraw_one_coin(pool, lpIn, 0);

        // todo: need to divide by GMU
        return arthUsdOut.div(2);
    }

    function estimateARTHtoBuy(
        uint256 daiToSell,
        uint256 usdcToSell,
        uint256 usdtToSell
    ) external view override returns (uint256) {
        uint256[4] memory amountsIn = [0, daiToSell, usdcToSell, usdtToSell];

        uint256 lpIn = zap.calc_token_amount(pool, amountsIn, true);
        uint256 arthUsdOut = zap.calc_withdraw_one_coin(pool, lpIn, 0);

        // todo: need to divide by GMU
        return arthUsdOut.div(2);
    }

    function _flush(address to) internal {
        if (arthUsd.balanceOf(me) > 0) {
            arthUsd.withdraw(arthUsd.balanceOf(me).div(2));
        }

        if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
        if (usdc.balanceOf(me) > 0) usdc.transfer(to, usdc.balanceOf(me));
        if (lp.balanceOf(me) > 0) lp.transfer(to, lp.balanceOf(me));
        if (usdt.balanceOf(me) > 0) usdt.transfer(to, usdt.balanceOf(me));
        if (dai.balanceOf(me) > 0) dai.transfer(to, dai.balanceOf(me));
    }

    function _removeLiquidityOneCoin(
        uint256 burnAmount,
        int128 i,
        uint256 minReceived
    ) internal {
        (bool success, ) = address(zap).call(
            abi.encodeWithSignature(
                "remove_liquidity_one_coin(address,uint256,int128,uint256)",
                pool,
                burnAmount,
                i,
                minReceived
            )
        );

        require(success, "CurveARTHRouter: remove_liquidity_one_coin failed");
    }

    function _addLiquidity(uint256[4] memory depositAmounts, uint256 minMintAmount) internal {
        (bool success, ) = address(zap).call(
            abi.encodeWithSignature(
                "add_liquidity(address,uint256[4],uint256)",
                pool,
                depositAmounts,
                minMintAmount
            )
        );

        require(success, "CurveARTHRouter: add_liquidity failed");
    }
}
