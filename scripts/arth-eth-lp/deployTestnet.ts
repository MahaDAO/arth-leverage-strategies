/* eslint-disable */

import { BigNumber } from "ethers";
import hre, { ethers, network } from "hardhat";
import { wait } from "../utils";

async function main() {
  console.log(`Deploying to ${network.name}...`);
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer address is ${deployer.address}.`);

  const fee = "3000";
  const mahaAddr = "0xDe8bBcd75338b51d9518F082E8E523167911814d";
  const arthAddr = "0xb65865fEBa151a95cDb103a8a01161eBCda30089";
  const wethAddr = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6";
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
  const borrowerOperationsAddr = "0xda672e23BD07f210E2e214B7460Cb9905b9B92c2";
  const priceFeedAddr = "0x8Ff446c8C593065E4594E64B424A8EfDAeA1129C";
  const troveManagerAddr = "0x497b7eE193AFd52167d46c4EfBB233Ee72dadD01";
  const uniswapV3SwapRouterAddr = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
  const uniswapNFTPositionMangerAddr = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";

  const arth = await ethers.getContractAt("IERC20", arthAddr);
  const weth = await ethers.getContractAt("IERC20", wethAddr);
  const maha = await ethers.getContractAt("MockERC20", mahaAddr);

  const ARTHETHTroveLP = await ethers.getContractFactory("ARTHETHTroveLP");
  console.log('Deploying...')
  const arthEthTroveLp = await ARTHETHTroveLP.connect(deployer).deploy(
    borrowerOperationsAddr,
    uniswapNFTPositionMangerAddr,
    arthAddr,
    mahaAddr,
    wethAddr,
    fee,
    uniswapV3SwapRouterAddr,
    priceFeedAddr,
    false
  );
  await arthEthTroveLp.deployed();
  console.log("ARTHETHTRoveLP deployed at", arthEthTroveLp.address);
  console.log('Opening trove...')
  const tx = await arthEthTroveLp.connect(deployer).openTrove(
    "1000000000000000000",
    "251000000000000000000",
    ZERO_ADDRESS,
    ZERO_ADDRESS,
    ZERO_ADDRESS,
    { value: "10000000000000000" }
  );
  await tx.wait();
  await hre.run("verify:verify", {
    address: arthEthTroveLp.address,
    constructorArguments: [
        borrowerOperationsAddr,
        uniswapNFTPositionMangerAddr,
        arthAddr,
        mahaAddr,
        wethAddr,
        fee,
        uniswapV3SwapRouterAddr,
        priceFeedAddr,
        false
    ]
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
