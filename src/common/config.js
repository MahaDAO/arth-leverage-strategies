const { FeeAmount } = require('@uniswap/v3-sdk')
const { ARTH_TOKEN, WETH_TOKEN } = require('./constants')

exports.CurrentConfig = {
  tokens: {
    in: WETH_TOKEN,
    amountIn: 1,
    out: ARTH_TOKEN,
    poolFee: FeeAmount.MEDIUM,
  }
}
