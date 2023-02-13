  // const { ethers } = require('ethers')
  const { ethers } = require('hardhat')
  
  const ERC20_ABI = require("../common/abi/ERC20.json")
  const {
    SWAP_ROUTER_ADDRESS,
    ADDRESSES
  } = require('../common/constants')

  const UniswapRouterABI = require('../common/abi/UniswapV3Router_ABI.json')
  const WETH_ABI = require('../common/abi/WETH_ABI.json')
  const LendingPoolABI = require('../common/abi/LendingPoolABI.json')
  const AaveOracleABI = require('../common/abi/AaveOracle.json')
  
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

  exports.sellETHForUSDC = async (wallet, amount) => {
    try{
      const USDCContract = await ethers.getContractAt(ERC20_ABI, ADDRESSES['MAINNET']['USDC'], wallet)
      const oldValue = await USDCContract.balanceOf(wallet.address)
      const WETH_Contract = await ethers.getContractAt(WETH_ABI, ADDRESSES['MAINNET']['WETH'], wallet)
      await WETH_Contract.deposit({value: amount.toString()});
  
      await WETH_Contract.approve(SWAP_ROUTER_ADDRESS, amount.toString())
  
      const routerContract = await ethers.getContractAt(UniswapRouterABI, SWAP_ROUTER_ADDRESS, wallet);
      await routerContract.exactInputSingle([
        ADDRESSES['MAINNET']['WETH'],
        ADDRESSES['MAINNET']['USDC'],
        "10000",
        wallet.address,
        (Math.floor(new Date().getTime() / 1000) + 1000).toString(),
        amount,
        "0",
        "0"
      ])
      const newValue = await USDCContract.balanceOf(wallet.address)
      // test mode
      console.log('------------- balalnce of USDC -----------------', newValue.sub(oldValue).toString())
      return newValue.sub(oldValue);
    } catch (e) {
      console.log(" error ", e)
      throw new Error(e);
    }
    
  }

  exports.depositAndBorrow = async (wallet, amount) => {
    try {
      console.log("************************  deposit and borrow *****************************")
      const lendingPoolContract = await ethers.getContractAt(LendingPoolABI, ADDRESSES['MAINNET']['LendingPool'], wallet)
      const USDCContract = await ethers.getContractAt(ERC20_ABI, ADDRESSES['MAINNET']['USDC'], wallet)
      const AaveOracle = await ethers.getContractAt(AaveOracleABI, ADDRESSES['MAINNET']['AaveOracle'], wallet)
      const ArthContract = await ethers.getContractAt(ERC20_ABI, ADDRESSES['MAINNET']['ARTH'], wallet)
      const oldValue = await ArthContract.balanceOf(wallet.address)
      await USDCContract.approve(lendingPoolContract.address, amount)
      await lendingPoolContract.deposit(ADDRESSES['MAINNET']['USDC'], amount, wallet.address, 0)
      const ArthPrice = await AaveOracle.getAssetPrice(ADDRESSES['MAINNET']['ARTH'])
      let userData = await lendingPoolContract.getUserAccountData(wallet.address)
      const ArthAmount = (userData.availableBorrowsBase).mul('1000000000000000000').div(ArthPrice)
      await lendingPoolContract.borrow(ADDRESSES['MAINNET']['ARTH'], ArthAmount, 1, 0, wallet.address)
      userData = await lendingPoolContract.getUserAccountData(wallet.address)
      console.log('--------------arth balance-------------', (await ArthContract.balanceOf(wallet.address)).toString())
      const newValue = await ArthContract.balanceOf(wallet.address)
      return newValue.sub(oldValue);
    } catch(e) {
      console.log(" error ", e)
      throw new Error(e);
    }
  }

  exports.sellARTH = async (wallet, amount) => {
    try{
      console.log("************************  sell Arth *****************************")
      const arthContract = await ethers.getContractAt(ERC20_ABI, ADDRESSES['MAINNET']['ARTH'], wallet)
      const WETH_Contract = await ethers.getContractAt(WETH_ABI, ADDRESSES['MAINNET']['WETH'], wallet)
      const oldValue = await WETH_Contract.balanceOf(wallet.address)
  
      console.log("-------------------amountIn--------------",amount)
      await arthContract.approve(SWAP_ROUTER_ADDRESS, amount.toString())
  
      const routerContract = await ethers.getContractAt(UniswapRouterABI, SWAP_ROUTER_ADDRESS, wallet);
      await routerContract.exactInputSingle([
        ADDRESSES['MAINNET']['ARTH'],
        ADDRESSES['MAINNET']['WETH'],
        "10000",
        wallet.address,
        (Math.floor(new Date().getTime() / 1000) + 1000).toString(),
        amount.toString(),
        "0",
        "0"
      ])
      const newValue = await WETH_Contract.balanceOf(wallet.address)
      await WETH_Contract.withdraw(newValue.sub(oldValue))
      // test mode
      console.log('WETH balance--------------', newValue.sub(oldValue).toString())
      console.log('------------- balalnce of ether -----------------', (await wallet.provider.getBalance(wallet.address)).toString())
      return newValue.sub(oldValue);
    } catch (e) {
      console.log(" error ", e)
      throw new Error(e);
    }
    
  }