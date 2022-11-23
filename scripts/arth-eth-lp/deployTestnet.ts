/* eslint-disable */

import { BigNumber } from "ethers";
import hre, { ethers, network } from "hardhat";
import { wait } from "../utils";

async function main() {
  console.log(`Deploying to ${network.name}...`);
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer address is ${deployer.address}.`);

  const fee = "3000";
  const mahaAddr = "0x0Ac047155dfc292598503e31EBa58F988F0De76d";
  const arthAddr = "0xCA8E3F4967c96D94Acbe8D1b78b6520cEEfe3810";
  const wethAddr = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6";
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
  const borrowerOperationsAddr = "0xEb81E0b7470e77E034C59A9886b6C67197Fd2E0A";
  const priceFeedAddr = "0x10fc058fc6c4e011c3369bC8C909a853d36ffFa0";
  const uniswapV3SwapRouterAddr = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
  const uniswapNFTPositionMangerAddr = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
  const poolAddr = "0x7d335a784C35Adf1ca51765B68B658D928cD0a70";

  const arth = await ethers.getContractAt("IERC20", arthAddr);
  const weth = await ethers.getContractAt("IERC20", wethAddr);
  const maha = await ethers.getContractAt("MockERC20", mahaAddr);

  const ARTHETHTroveLP = await ethers.getContractFactory("ARTHETHTroveLP");
  const ARTHETHRouter = await ethers.getContractFactory("ARTHETHRouter");

  console.log('Deploying ARTH-ETH router');
  const arthEthRouter = await ARTHETHRouter.connect(deployer).deploy(
    arthAddr,
    wethAddr,
    fee,
    uniswapV3SwapRouterAddr
  );
  await arthEthRouter.deployed();
  console.log("ARTHETHRouter deployed at", arthEthRouter.address);

  console.log('Deploying strategy');
  const arthEthTroveLp = await ARTHETHTroveLP.connect(deployer).deploy(
    borrowerOperationsAddr,
    uniswapNFTPositionMangerAddr,
    arthAddr,
    mahaAddr,
    wethAddr,
    fee,
    arthEthRouter.address,
    priceFeedAddr,
    poolAddr
  );
  await arthEthTroveLp.deployed();
  console.log("ARTHETHTRoveLP deployed at", arthEthTroveLp.address);
  console.log('Opening trove...')
  const tx = await arthEthTroveLp.connect(deployer).openTrove(
    "1000000000000000000",
    "351000000000000000000",
    ZERO_ADDRESS,
    ZERO_ADDRESS,
    ZERO_ADDRESS,
    { value: "150000000000000000" }
  );
  await tx.wait();
//   await hre.run("verify:verify", {
//     address: arthEthTroveLp.address,
//     constructorArguments: [
//         borrowerOperationsAddr,
//         uniswapNFTPositionMangerAddr,
//         arthAddr,
//         mahaAddr,
//         wethAddr,
//         fee,
//         uniswapV3SwapRouterAddr,
//         priceFeedAddr,
//         poolAddr
//     ]
//   });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
