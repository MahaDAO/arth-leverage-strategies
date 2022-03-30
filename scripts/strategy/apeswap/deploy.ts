import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../utils";

async function main() {
  console.log("deploying QuickSwapExposure");
  // We get the contract to deploy
  const QuickSwapExposure = await ethers.getContractFactory("ApeSwapExposure");
  const instance = await QuickSwapExposure.deploy(
    "0x91aBAa2ae79220f68C0C76Dd558248BA788A71cD", // address _flashloan,
    "0xb69a424df8c737a122d0e60695382b3eec07ff4b", // address _arth,
    "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", // address _usdc,
    "0xe9e7cea3dedca5984780bafc599bd69add087d56", // address _busd,
    "0x603c7f932ed1fc6575303d8fb018fdcbb0f39a95", // address _rewardToken,
    "0x16f3022DD080FeCDf0C02D4F793838f7a698599a", // address _ellipsis,
    "0x88fd584df3f97c64843cd474bdc6f78e398394f4", // address _arthUsd,
    "0xcf0febd3f17cef5b47b0cd257acf6025c5bff3b7" // address _uniswapRouter
  );

  await instance.deployed();
  console.log("QuickSwapExposure deployed to:", instance.address);

  await instance.init(
    "0x3f3cdCC49599600EeaF7c6e11Da2E377BDEE95cA", // address _borrowerOperations,
    "0x0F7e695770E1bC16a9A899580828e22B16d93314", // address _troveManager,
    "0x9c66D9475e8492963F98c8B2642C8e5F50EE695f", // address _priceFeed,
    "0xc4bBeFDc3066b919cd1A6B5901241E11282e625D", // address _recorder,
    "0xBb9858603B1FB9375f6Df972650343e985186Ac5", // address _stakingWrapper,
    "0x3A076D0EBF9ff41473071864bf23Afdbd77A253E" // address _accountRegistry
  );

  console.log("done init");

  await wait(20 * 1000); // wait for a minute

  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments: [
      "0x9a9c25d9e304ddb284e5a36be0cdee0a58ac3c04", // address _flashloan,
      "0xE2fE4C3422C112382ffC7D68f7B10a7cC2958458", // address _controller,
      "0xE52509181FEb30EB4979E29EC70D50FD5C44D590", // address _arth,
      "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // address _usdc,
      "0xc2132d05d31c914a87c6611c10748aeb04b58e8f", // address _usdt,
      "0xf28164a485b0b2c90639e47b0f377b4a438a16b1", // address _rewardToken,
      "0x5ab5c56b9db92ba45a0b46a207286cd83c15c939", // address _curveRouter,
      "0xDdE5FdB48B2ec6bc26bb4487f8E3a4EB99b3d633", // address _clp,
      "0x84f168e646d31f6c33fdbf284d9037f59603aa28", // address _arthUsd,
      "0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff" // address _uniswapRouter
    ]
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
