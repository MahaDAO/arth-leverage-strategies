const IUniswapV3PoolABI = require('@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json')
const { ethers } = require('hardhat')
// const { ethers } = require('ethers')
const { ADDRESSES } = require('../common/constants')

exports.getPoolInfo =  async (provider) => {
  console.log("------------getPoolInfo----------------")
  const poolContract = await ethers.getContractAt(
    IUniswapV3PoolABI.abi,
    ADDRESSES['MAINNET']['POOL'],
  )
  console.log("------------getPoolInfo    2----------------")

  const [token0, token1, fee, tickSpacing, liquidity, slot0] =
    await Promise.all([
      poolContract.token0(),
      poolContract.token1(),
      poolContract.fee(),
      poolContract.tickSpacing(),
      poolContract.liquidity(),
      poolContract.slot0(),
    ])
  console.log("------------getPoolInfo    3----------------", token0, token1, fee.toString(), tickSpacing.toString(), liquidity.toString())
  return {
    token0,
    token1,
    fee,
    tickSpacing,
    liquidity,
    sqrtPriceX96: slot0[0],
    tick: slot0[1],
  }
}
