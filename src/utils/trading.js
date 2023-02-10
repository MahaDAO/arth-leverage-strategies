  // const { ethers } = require('ethers')
  const { ethers } = require('hardhat')
  
  const ERC20_ABI = require("../common/abi/ERC20.json")
  const {
    SWAP_ROUTER_ADDRESS,
    ADDRESSES
  } = require('../common/constants')

  const UniswapRouterABI = require('../common/abi/UniswapV3Router_ABI.json')
  const WETH_ABI = require('../common/abi/WETH_ABI.json')
  
  // Trading Functions
  
  exports.createTrade = async (wallet, amount) => {
    try{
      const arthContract = await ethers.getContractAt(ERC20_ABI, ADDRESSES['MAINNET']['ARTH'], wallet)
      const oldValue = await arthContract.balanceOf(wallet.address)
      const WETH_Contract = await ethers.getContractAt(WETH_ABI, ADDRESSES['MAINNET']['WETH'], wallet)
      await WETH_Contract.deposit({value: amount.toString()});
  
      await WETH_Contract.approve(SWAP_ROUTER_ADDRESS, amount.toString())
      console.log("-------------------amountIn--------------",amount.toString())
  
      const routerContract = await ethers.getContractAt(UniswapRouterABI, SWAP_ROUTER_ADDRESS, wallet);
      await routerContract.exactInputSingle([
        ADDRESSES['MAINNET']['WETH'],
        ADDRESSES['MAINNET']['ARTH'],
        "10000",
        wallet.address,
        (Math.floor(new Date().getTime() / 1000) + 1000).toString(),
        amount.toString(),
        "0",
        "0"
      ])
      const newValue = await arthContract.balanceOf(wallet.address)
      // test mode
      console.log('------------- balalnce of arth -----------------', await arthContract.balanceOf(wallet.address))
      return newValue.sub(oldValue);
    } catch (e) {
      console.log(" error ", e)
      return ethers.BigNumber.from(0)
    }
    
  }