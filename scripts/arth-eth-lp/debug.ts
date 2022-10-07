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
  const mahaAddr = "0xb4d930279552397bba2ee473229f89ec245bc365";
  const arthAddr = "0x8CC0F052fff7eaD7f2EdCCcaC895502E884a8a71";
  const wethAddr = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
  const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
  const uniswapV3PoolAddr = "0xfD6c2A0674796D0452534846f4c90923352C716b";
  const borrowerOperationsAddr = "0xD3761E54826837B8bBd6eF0A278D5b647B807583";
  const uniswapV3SwapRouterAddr = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
  const uniswapNFTPositionMangerAddr = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
  const troveManager = "0xF4eD5d0C3C977B57382fabBEa441A63FAaF843d3";
  const priceFeed = "0x15726a29c398e65Ae5dA551DFf3BBC26D767d0F7";
  
  const arth = await ethers.getContractAt("IERC20", arthAddr);
  const weth = await ethers.getContractAt("IERC20", wethAddr);

  const ARTHETHTroveLP = await ethers.getContractFactory("ARTHETHTroveLP");
  console.log('Deploying...')
  const arthEthTroveLp = await ARTHETHTroveLP.connect(impersonatedSigner).deploy(
    borrowerOperationsAddr,
    uniswapNFTPositionMangerAddr,
    arthAddr,
    mahaAddr,
    wethAddr,
    fee,
    uniswapV3SwapRouterAddr,
    priceFeed,
    troveManager
  );
  console.log("ARTHETHTRoveLp deployed at", arthEthTroveLp.address);
  console.log('Opening trove...')
  const a = {
        maxFee: "1000000000000000000", 
        upperHint: "0x0000000000000000000000000000000000000000",
        lowerHint: "0x0000000000000000000000000000000000000000",
  }
  const b = {
    amount0Desired:  "238666666666666666666",
    amount0Min: "0",
    amount1Desired: "1000000000000000000",
    amount1Min: "0",
    deadline: 16651024459,
    fee: "3000",
    recipient: "0x1904c4712ae18b0adf985c9102f54127b0455e35",
    tickLower: "-73260",
    tickUpper: "-62160",
    token0: "0x8CC0F052fff7eaD7f2EdCCcaC895502E884a8a71",
    token1: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
};
await arthEthTroveLp.connect(impersonatedSigner).openTrove(
    "1000000000000000000",
    "251000000000000000000",
    ZERO_ADDRESS,
    ZERO_ADDRESS,
    ZERO_ADDRESS,
    { value: "1000000000000000000"}
  );
  console.log('Depositing');
  await arthEthTroveLp.connect(impersonatedSigner).deposit(
    "448666666666666666666",
    "1000000000000000000",
    a,
    b,
    1,
    [],
    { value: "2000000000000000000"}
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
