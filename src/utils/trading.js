const {
    CurrencyAmount,
    Percent,
    Ether,
    SupportedChainId,
    TradeType,
  } = require('@uniswap/sdk-core')
  const {
    Pool,
    Route,
    SwapQuoter,
    SwapRouter,
    Trade,
  } = require('@uniswap/v3-sdk')
  const { ethers } = require('ethers')
  const JSBI = require('jsbi')
  
  const { CurrentConfig } = require('../common/config')
  const ERC20_ABI = require("../common/abi/ERC20.json")
  const {
    QUOTER_CONTRACT_ADDRESS,
    SWAP_ROUTER_ADDRESS,
    MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS
  } = require('../common/constants')
  const { getPoolInfo } = require('./pool')
  const {
    sendTransaction,
  } = require('./providers')
  
  function fromReadableAmount(amount, decimals) {
    const extraDigits = Math.pow(10, countDecimals(amount))
    const adjustedAmount = amount * extraDigits
    return JSBI.divide(
      JSBI.multiply(
        JSBI.BigInt(adjustedAmount),
        JSBI.exponentiate(JSBI.BigInt(10), JSBI.BigInt(decimals))
      ),
      JSBI.BigInt(extraDigits)
    )
  }
  
  // Trading Functions
  
  exports.createTrade = async () => {
    const poolInfo = await getPoolInfo()
  
    const pool = new Pool(
      CurrentConfig.tokens.in,
      CurrentConfig.tokens.out,
      CurrentConfig.tokens.poolFee,
      poolInfo.sqrtPriceX96.toString(),
      poolInfo.liquidity.toString(),
      poolInfo.tick
    )
  
    const swapRoute = new Route(
      [pool],
      Ether.onChain(SupportedChainId.MAINNET),
      CurrentConfig.tokens.out
    )
  
    const amountOut = await getOutputQuote(swapRoute)
  
    const uncheckedTrade = Trade.createUncheckedTrade({
      route: swapRoute,
      inputAmount: CurrencyAmount.fromRawAmount(
        CurrentConfig.tokens.in,
        fromReadableAmount(
          CurrentConfig.tokens.amountIn,
          CurrentConfig.tokens.in.decimals
        ).toString()
      ),
      outputAmount: CurrencyAmount.fromRawAmount(
        CurrentConfig.tokens.out,
        JSBI.BigInt(amountOut)
      ),
      tradeType: TradeType.EXACT_INPUT,
    })
  
    return uncheckedTrade
  }
  
  exports.executeTrade = async(
    trade,
    wallet,
    amount
  ) => {
    const provider = wallet.provider;
  
    if (!provider) {
      throw new Error('Cannot execute a trade without a connected wallet')
    }
  
    // Give approval to the router to spend the token
    const tokenApproval = await getTokenTransferApproval(CurrentConfig.tokens.in, wallet, amount)
  
    // Fail if transfer approvals do not go through
    if (tokenApproval !== 'Sent') {
      return 'Failed'
    }
  
    const options = {
      slippageTolerance: new Percent(500, 10000), // 50 bips, or 0.50%
      deadline: Math.floor(Date.now() / 1000) + 60 * 20, // 20 minutes from the current Unix time
      recipient: wallet.address,
    }
  
    const methodParameters = SwapRouter.swapCallParameters([trade], options)
  
    const tx = {
      data: methodParameters.calldata,
      to: SWAP_ROUTER_ADDRESS,
      value: methodParameters.value,
      from: wallet.address,
      maxFeePerGas: MAX_FEE_PER_GAS,
      maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS,
    }
  
    const res = await sendTransaction(tx)
  
    return res
  }
  
  // Helper Quoting and Pool Functions
  
  async function getOutputQuote(route, wallet) {
    const provider = wallet.provider
  
    if (!provider) {
      throw new Error('Provider required to get pool state')
    }
  
    const { calldata } = await SwapQuoter.quoteCallParameters(
      route,
      CurrencyAmount.fromRawAmount(
        Ether.onChain(SupportedChainId.MAINNET),
        fromReadableAmount(
          CurrentConfig.tokens.amountIn,
          CurrentConfig.tokens.in.decimals
        )
      ),
      TradeType.EXACT_INPUT,
      {
        useQuoterV2: true,
      }
    )
  
    const quoteCallReturnData = await provider.call({
      to: QUOTER_CONTRACT_ADDRESS,
      data: calldata,
    })
  
    return ethers.utils.defaultAbiCoder.decode(['uint256'], quoteCallReturnData)
  }
  
  async function getTokenTransferApproval(
    token,
    wallet,
    amount
  ) {
    const provider = wallet.provider
    if (!provider) {
      console.log('No Provider Found')
      return "Failed"
    }
  
    try {
      const tokenContract = new ethers.Contract(
        token.address,
        ERC20_ABI,
        provider
      )

      if((await tokenContract.allowance(wallet.address, SWAP_ROUTER_ADDRESS)).gt(amount)) return 'Sent';

      const transaction = await tokenContract.populateTransaction.approve(
        SWAP_ROUTER_ADDRESS,
        "99999999999999999999999999999999999"
      )
  
      return sendTransaction({
        ...transaction,
        from: wallet.address,
      })
    } catch (e) {
      console.error(e)
      return "Failed"
    }
  }
  