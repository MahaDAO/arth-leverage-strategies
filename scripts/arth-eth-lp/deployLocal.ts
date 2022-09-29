/* eslint-disable */

import { ethers, network } from "hardhat";
import { wait } from "../utils";

async function main() {
  console.log(`Debugging to ${network.name}...`);

  const [deployer] = await ethers.getSigners();

  const address = "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B";
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [address],
  });
  const impersonatedSigner = await ethers.getSigner(address);

  console.log(`Deployer address is ${deployer.address}.`);

  const fee = "3000";
  const arthAddr = "0x8CC0F052fff7eaD7f2EdCCcaC895502E884a8a71";
  const wethAddr = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
  const uniswapV3PoolAddr = "0xfD6c2A0674796D0452534846f4c90923352C716b";
  const borrowerOperationsAddr = "0xD3761E54826837B8bBd6eF0A278D5b647B807583";
  const uniswapV3SwapRouterAddr = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
  const uniswapNFTPositionMangerAddr = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
  
  const arth = await ethers.getContractAt("IERC20", arthAddr);
  const weth = await ethers.getContractAt("IERC20", wethAddr);

  const ARTHETHTroveLP = await ethers.getContractFactory("ARTHETHTroveLP");
  console.log('Deploying...')
  const arthEthTroveLp = await ARTHETHTroveLP.connect(impersonatedSigner).deploy(
    borrowerOperationsAddr,
    uniswapNFTPositionMangerAddr,
    arthAddr,
    wethAddr,
    fee,
    uniswapV3SwapRouterAddr
  );
  console.log("ARTHETHTRoveLp deployed at", arthEthTroveLp.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
