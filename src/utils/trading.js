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
  // const { ethers } = require('ethers')
  const { ethers } = require('hardhat')
  const JSBI = require('jsbi')
  
  const { CurrentConfig } = require('../common/config')
  const ERC20_ABI = require("../common/abi/ERC20.json")
  const {
    QUOTER_CONTRACT_ADDRESS,
    SWAP_ROUTER_ADDRESS,
    MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS,
    ADDRESSES
  } = require('../common/constants')
  const { getPoolInfo } = require('./pool')
  const {
    sendTransaction,
  } = require('./providers')

  const UniswapRouterABI = require('../common/abi/UniswapV3Router_ABI.json')
  const WETH_ABI = require('../common/abi/WETH_ABI.json')

  function countDecimals(x) {
    if (Math.floor(x) === x) {
      return 0
    }
    return x.toString().split('.')[1].length || 0
  }
  
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
  
  exports.createTrade = async (wallet, amount) => {
    const WETH_Contract = await ethers.getContractAt(WETH_ABI, ADDRESSES['MAINNET']['WETH'], wallet)
    await WETH_Contract.deposit({value: amount.toString()});

    await WETH_Contract.approve(SWAP_ROUTER_ADDRESS, amount.toString())

    const routerContract = await ethers.getContractAt(UniswapRouterABI, SWAP_ROUTER_ADDRESS, wallet);
    console.log("----------------trading block.timestamp-------------", (Math.floor(new Date().getTime() / 1000) + 1000).toString())
    await routerContract.exactInputSingle([
      ADDRESSES['MAINNET']['WETH'],
      ADDRESSES['MAINNET']['ARTH'],
      "3000",
      wallet.address,
      (Math.floor(new Date().getTime() / 1000) + 1000).toString(),
      amount.toString(),
      "0",
      "0"
    ])

    const arthContract = await ethers.getContractAt(ERC20_ABI, ADDRESSES['MAINNET']['ARTH'], wallet)
    console.log('------------- balalnce of arth -----------------', await arthContract.balanceOf(wallet.address))
    // const poolInfo = await getPoolInfo()
  
    // const pool = new Pool(
    //   CurrentConfig.tokens.in,
    //   CurrentConfig.tokens.out,
    //   CurrentConfig.tokens.poolFee,
    //   poolInfo.sqrtPriceX96.toString(),
    //   poolInfo.liquidity.toString(),
    //   poolInfo.tick
    // )
  
    // const swapRoute = new Route(
    //   [pool],
    //   Ether.onChain(SupportedChainId.MAINNET),
    //   CurrentConfig.tokens.out
    // )
    // console.log("------------------createTrade------------------ 1")
    // const amountOut = await getOutputQuote(swapRoute, wallet)

    // console.log('------------------getAmountOut-----------------', amountOut.toString())

    // const uncheckedTrade = Trade.createUncheckedTrade({
    //   route: swapRoute,
    //   inputAmount: CurrencyAmount.fromRawAmount(
    //     CurrentConfig.tokens.in,
    //     fromReadableAmount(
    //       CurrentConfig.tokens.amountIn,
    //       CurrentConfig.tokens.in.decimals
    //     ).toString()
    //   ),
    //   outputAmount: CurrencyAmount.fromRawAmount(
    //     CurrentConfig.tokens.out,
    //     JSBI.BigInt(amountOut)
    //   ),
    //   tradeType: TradeType.EXACT_INPUT,
    // })
  
    // return uncheckedTrade
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
    console.log('--------------------------------- getOutputQuote------------------------')
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
    console.log('--------------------------------- getOutputQuote  2------------------------', calldata)
  
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
      const tokenContract = await ethers.getContractAt(
        ERC20_ABI,
        token.address,
      )
      console.log("------approve amount----------", (await tokenContract.allowance(wallet.address, SWAP_ROUTER_ADDRESS)).toString())
      if((await tokenContract.allowance(wallet.address, SWAP_ROUTER_ADDRESS)).gt(amount)) return 'Sent';

      await tokenContract.connect(wallet).approve(
        SWAP_ROUTER_ADDRESS,
        "99999999999999999999999999999999999"
      )
  
      return "Sent"
    } catch (e) {
      console.error(e)
      return "Failed"
    }
  }
  