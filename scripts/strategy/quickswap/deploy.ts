import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const QuickSwapExposure = await ethers.getContractFactory("QuickSwapExposure");
  const instance = await QuickSwapExposure.deploy(
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
  );

  await instance.deployed();
  console.log("QuickSwapExposure deployed to:", instance.address);

  await instance.init(
    "0x123086374B0fCe322EbDb7CBbFe454856Ef88524", // address _borrowerOperations,
    "0x2d1F24127AE8670eB9A9a36E81420fb030Ea953D", // address _troveManager,
    "0xe40805D1eA67265Cce0315243F4DEAddD9c611a9", // address _priceFeed,
    "0x84f168e646d31f6c33fdbf284d9037f59603aa28", // address _arthUsd,
    "0xc4bBeFDc3066b919cd1A6B5901241E11282e625D", // address _recorder,
    "0x4AE43De251E7c836098605da4C11133d335203b1", // address _stakingWrapper,
    "0x7cA30e86f73528138ace8f4922B96975C53D89D6" // address _accountRegistry
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
      "0xDdE5FdB48B2ec6bc26bb4487f8E3a4EB99b3d633", // address _cpool,
      "0x84f168e646d31f6c33fdbf284d9037f59603aa28", // address _arthUsd,

      // // address _stakingWrapper,
      // // address _accountRegistry,
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
