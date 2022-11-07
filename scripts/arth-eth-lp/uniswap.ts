/* eslint-disable no-unused-vars */
import { Currency, CurrencyAmount, Price, Token } from "@uniswap/sdk-core";
import {
    encodeSqrtRatioX96,
    FeeAmount,
    nearestUsableTick,
    priceToClosestTick,
    TICK_SPACINGS,
    TickMath,
    Position,
    Pool,
    tickToPrice
} from "@uniswap/v3-sdk";
import { parseUnits } from "ethers/lib/utils";
import JSBI from "jsbi";

export enum Field {
    CURRENCY_A = "CURRENCY_A",
    CURRENCY_B = "CURRENCY_B"
}

export enum Bound {
    LOWER = "LOWER",
    UPPER = "UPPER"
}

export enum PoolState {
    LOADING,
    NOT_EXISTS,
    EXISTS,
    INVALID
}

export type FullRange = true;
export const BIG_INT_ZERO = JSBI.BigInt(0);

interface MintState {
    readonly independentField: Field;
    readonly typedValue: string;
    readonly startPriceTypedValue: string; // for the case when there's no liquidity
    readonly leftRangeTypedValue: string | FullRange;
    readonly rightRangeTypedValue: string | FullRange;
}

const initialState: MintState = {
    independentField: Field.CURRENCY_A,
    typedValue: "",
    startPriceTypedValue: "",
    leftRangeTypedValue: "",
    rightRangeTypedValue: ""
};

export function getTickToPrice(
    baseToken?: Token,
    quoteToken?: Token,
    tick?: number
): Price<Token, Token> | undefined {
    if (!baseToken || !quoteToken || typeof tick !== "number") {
        return undefined;
    }

    return tickToPrice(baseToken, quoteToken, tick);
}

/**
 * Parses a CurrencyAmount from the passed string.
 * Returns the CurrencyAmount, or undefined if parsing fails.
 */
export default function tryParseCurrencyAmount<T extends Currency>(
    value?: string,
    currency?: T
): CurrencyAmount<T> | undefined {
    if (!value || !currency) {
        return undefined;
    }
    try {
        const typedValueParsed = parseUnits(value, currency.decimals).toString();
        if (typedValueParsed !== "0") {
            return CurrencyAmount.fromRawAmount(currency, JSBI.BigInt(typedValueParsed));
        }
    } catch (error) {
        // fails if the user specifies too many decimal places of precision (or maybe exceed max uint?)
        console.debug(`Failed to parse input amount: "${value}"`, error);
    }
    return undefined;
}

export function useV3DerivedMintInfo(
    currencyAval: CurrencyAmount<Currency>,
    currencyBval: CurrencyAmount<Currency>,
    feeAmount: FeeAmount,
    leftRangeTypedValue: string,
    rightRangeTypedValue: string,
    baseCurrency: Currency,
    pool: Pool
): {
    pool?: Pool | null;
    ticks: { [bound in Bound]?: number | undefined };
    price?: Price<Token, Token>;
    pricesAtTicks: {
        [bound in Bound]?: Price<Token, Token> | undefined;
    };
    currencies: { [field in Field]?: Currency };
    dependentField: Field;
    parsedAmounts: { [field in Field]?: CurrencyAmount<Currency> };
    position: Position | undefined;
    ticksAtLimit: { [bound in Bound]?: boolean | undefined };
} {
    const { independentField, startPriceTypedValue } = initialState;

    const dependentField =
        independentField === Field.CURRENCY_A ? Field.CURRENCY_B : Field.CURRENCY_A;

    const currencyA = currencyAval.currency;
    const currencyB = currencyBval.currency;

    // currencies
    const currencies: { [field in Field]?: Currency } = {
        [Field.CURRENCY_A]: currencyA,
        [Field.CURRENCY_B]: currencyB
    };

    // formatted with tokens
    const [tokenA, tokenB, baseToken] = [
        currencyA?.wrapped,
        currencyB?.wrapped,
        baseCurrency?.wrapped
    ];

    const [token0, token1] = tokenA.sortsBefore(tokenB) ? [tokenA, tokenB] : [tokenB, tokenA];

    // pool
    const poolState = PoolState.EXISTS;
    const noLiquidity = false; // poolState === PoolState.NOT_EXISTS;

    // note to parse inputs in reverse
    const invertPrice = Boolean(baseToken && token0 && !baseToken.equals(token0));

    // always returns the price with 0 as base token
    const price: Price<Token, Token> | undefined = (() => {
        // if no liquidity use typed value
        if (noLiquidity) {
            const parsedQuoteAmount = tryParseCurrencyAmount(
                startPriceTypedValue,
                invertPrice ? token0 : token1
            );
            if (parsedQuoteAmount && token0 && token1) {
                const baseAmount = tryParseCurrencyAmount("1", invertPrice ? token1 : token0);
                const price =
                    baseAmount && parsedQuoteAmount
                        ? new Price(
                              baseAmount.currency,
                              parsedQuoteAmount.currency,
                              baseAmount.quotient,
                              parsedQuoteAmount.quotient
                          )
                        : undefined;
                return (invertPrice ? price?.invert() : price) ?? undefined;
            }
            return undefined;
        } else {
            // get the amount of quote currency
            return pool && token0 ? pool.priceOf(token0) : undefined;
        }
    })();

    // if pool exists use it, if not use the mock pool
    const poolForPosition: Pool | undefined = pool;

    // lower and upper limits in the tick space for `feeAmoun<Trans>
    const tickSpaceLimits: {
        [bound in Bound]: number | undefined;
    } = {
        [Bound.LOWER]: feeAmount
            ? nearestUsableTick(TickMath.MIN_TICK, TICK_SPACINGS[feeAmount])
            : undefined,
        [Bound.UPPER]: feeAmount
            ? nearestUsableTick(TickMath.MAX_TICK, TICK_SPACINGS[feeAmount])
            : undefined
    };

    console.log("tickSpaceLimits", tickSpaceLimits);
    console.log("feeAmount", feeAmount);
    console.log("invertPrice", leftRangeTypedValue, rightRangeTypedValue);

    // parse typed range values and determine closest ticks
    // lower should always be a smaller tick
    const ticks: {
        [key: string]: number | undefined;
    } = (() => {
        return {
            [Bound.LOWER]:
                (invertPrice && typeof rightRangeTypedValue === "boolean") ||
                (!invertPrice && typeof leftRangeTypedValue === "boolean")
                    ? tickSpaceLimits[Bound.LOWER]
                    : invertPrice
                    ? tryParseTick(token1, token0, feeAmount, rightRangeTypedValue.toString())
                    : tryParseTick(token0, token1, feeAmount, leftRangeTypedValue.toString()),
            [Bound.UPPER]:
                (!invertPrice && typeof rightRangeTypedValue === "boolean") ||
                (invertPrice && typeof leftRangeTypedValue === "boolean")
                    ? tickSpaceLimits[Bound.UPPER]
                    : invertPrice
                    ? tryParseTick(token1, token0, feeAmount, leftRangeTypedValue.toString())
                    : tryParseTick(token0, token1, feeAmount, rightRangeTypedValue.toString())
        };
    })();

    const { [Bound.LOWER]: tickLower, [Bound.UPPER]: tickUpper } = ticks || {};

    // specifies whether the lower and upper ticks is at the exteme bounds
    const ticksAtLimit = {
        [Bound.LOWER]: feeAmount && tickLower === tickSpaceLimits.LOWER,
        [Bound.UPPER]: feeAmount && tickUpper === tickSpaceLimits.UPPER
    };

    // mark invalid range
    const invalidRange = Boolean(
        typeof tickLower === "number" && typeof tickUpper === "number" && tickLower >= tickUpper
    );

    // always returns the price with 0 as base token
    const pricesAtTicks = {
        [Bound.LOWER]: getTickToPrice(token0, token1, ticks[Bound.LOWER]),
        [Bound.UPPER]: getTickToPrice(token0, token1, ticks[Bound.UPPER])
    };

    // const dependentAmount: CurrencyAmount<Currency> | undefined = (() => {
    //     // we wrap the currencies just to get the price in terms of the other token
    //     const wrappedIndependentAmount = independentAmount?.wrapped;
    //     const dependentCurrency = dependentField === Field.CURRENCY_B ? currencyB : currencyA;
    //     if (
    //         independentAmount &&
    //         wrappedIndependentAmount &&
    //         typeof tickLower === "number" &&
    //         typeof tickUpper === "number" &&
    //         poolForPosition
    //     ) {
    //         const position: Position | undefined = wrappedIndependentAmount.currency.equals(
    //             poolForPosition.token0
    //         )
    //             ? Position.fromAmount0({
    //                   pool: poolForPosition,
    //                   tickLower,
    //                   tickUpper,
    //                   amount0: independentAmount.quotient,
    //                   useFullPrecision: true // we want full precision for the theoretical position
    //               })
    //             : Position.fromAmount1({
    //                   pool: poolForPosition,
    //                   tickLower,
    //                   tickUpper,
    //                   amount1: independentAmount.quotient
    //               });
    //         const dependentTokenAmount = wrappedIndependentAmount.currency.equals(
    //             poolForPosition.token0
    //         )
    //             ? position.amount1
    //             : position.amount0;
    //         return (
    //             dependentCurrency &&
    //             CurrencyAmount.fromRawAmount(dependentCurrency, dependentTokenAmount.quotient)
    //         );
    //     }
    //     return undefined;
    // })();

    const parsedAmounts: { [field in Field]: CurrencyAmount<Currency> | undefined } = {
        [Field.CURRENCY_A]: currencyAval,
        [Field.CURRENCY_B]: currencyBval
    };

    // single deposit only if price is out of range
    const deposit0Disabled = Boolean(
        typeof tickUpper === "number" && poolForPosition && poolForPosition.tickCurrent >= tickUpper
    );
    const deposit1Disabled = Boolean(
        typeof tickLower === "number" && poolForPosition && poolForPosition.tickCurrent <= tickLower
    );

    // create position entity based on users selection
    const position: Position | undefined = (() => {
        if (
            !poolForPosition ||
            !tokenA ||
            !tokenB ||
            typeof tickLower !== "number" ||
            typeof tickUpper !== "number" ||
            invalidRange
        )
            return undefined;

        // mark as 0 if disabled because out of range
        const amount0 = !deposit0Disabled
            ? parsedAmounts?.[
                  tokenA.equals(poolForPosition.token0) ? Field.CURRENCY_A : Field.CURRENCY_B
              ]?.quotient
            : BIG_INT_ZERO;
        const amount1 = !deposit1Disabled
            ? parsedAmounts?.[
                  tokenA.equals(poolForPosition.token0) ? Field.CURRENCY_B : Field.CURRENCY_A
              ]?.quotient
            : BIG_INT_ZERO;

        if (amount0 !== undefined && amount1 !== undefined) {
            return Position.fromAmounts({
                pool: poolForPosition,
                tickLower,
                tickUpper,
                amount0,
                amount1,
                useFullPrecision: true // we want full precision for the theoretical position
            });
        } else return undefined;
    })();

    return {
        dependentField,
        currencies,
        pool,
        parsedAmounts,
        ticks,
        price,
        pricesAtTicks,
        position,
        ticksAtLimit
    };
}

export function tryParsePrice(baseToken?: Token, quoteToken?: Token, value?: string) {
    if (!baseToken || !quoteToken || !value) return undefined;
    if (!value.match(/^\d*\.?\d+$/)) return undefined;

    const [whole, fraction] = value.split(".");

    const decimals = fraction?.length ?? 0;
    const withoutDecimals = JSBI.BigInt((whole ?? "") + (fraction ?? ""));

    return new Price(
        baseToken,
        quoteToken,
        JSBI.multiply(JSBI.BigInt(10 ** decimals), JSBI.BigInt(10 ** baseToken.decimals)),
        JSBI.multiply(withoutDecimals, JSBI.BigInt(10 ** quoteToken.decimals))
    );
}

export function tryParseTick(
    baseToken?: Token,
    quoteToken?: Token,
    feeAmount?: FeeAmount,
    value?: string
): number | undefined {
    if (!baseToken || !quoteToken || !feeAmount || !value) return undefined;

    const price = tryParsePrice(baseToken, quoteToken, value);
    if (!price) return undefined;

    let tick: number;

    // check price is within min/max bounds, if outside return min/max
    const sqrtRatioX96 = encodeSqrtRatioX96(price.numerator, price.denominator);

    if (JSBI.greaterThanOrEqual(sqrtRatioX96, TickMath.MAX_SQRT_RATIO)) {
        tick = TickMath.MAX_TICK;
    } else if (JSBI.lessThanOrEqual(sqrtRatioX96, TickMath.MIN_SQRT_RATIO)) {
        tick = TickMath.MIN_TICK;
    } else {
        // this function is agnostic to the base, will always return the correct tick
        tick = priceToClosestTick(price);
    }

    return nearestUsableTick(tick, TICK_SPACINGS[feeAmount]);
}
