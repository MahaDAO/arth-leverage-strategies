import { AbiCoder } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../utils";
import { initLibrary } from "../library";

async function main() {
  const { leverageLibrary, troveLibrary } = await initLibrary();

  console.log("deploying QuickswapUSDCUSDT");

  // We get the contract to deploy
  const QuickswapUSDCUSDT = await ethers.getContractFactory("QuickswapUSDCUSDT", {
    libraries: {
      LeverageLibrary: leverageLibrary.address,
      TroveLibrary: troveLibrary.address
    }
  });

  const args1 = [
    "0x9a9c25d9e304ddb284e5a36be0cdee0a58ac3c04", // address _flashloan,
    "0xE2fE4C3422C112382ffC7D68f7B10a7cC2958458", // address _controller,
    "0xE52509181FEb30EB4979E29EC70D50FD5C44D590", // address _arth,
    "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // address _usdc,
    "0xc2132d05d31c914a87c6611c10748aeb04b58e8f", // address _usdt,
    "0xf28164a485b0b2c90639e47b0f377b4a438a16b1", // address _rewardToken,
    "0xe5CBA8103594b98633d20F75264dd88EB8F64b30", // address _curve,
    "0x84f168e646d31f6c33fdbf284d9037f59603aa28", // address _arthUsd,
    "0xa5e0829caced8ffdd4de3c43696c57f7d7a678ff" // address _uniswapRouter
  ];

  const args2 = [
    "0x123086374B0fCe322EbDb7CBbFe454856Ef88524", // address _borrowerOperations,
    "0x2d1F24127AE8670eB9A9a36E81420fb030Ea953D", // address _troveManager,
    "0xe40805D1eA67265Cce0315243F4DEAddD9c611a9", // address _priceFeed,
    "0x54A4A4F6EA24863bda03972e281F3fb864AD3EBc", // address _stakingWrapper,
    "0x7cA30e86f73528138ace8f4922B96975C53D89D6" // address _accountRegistry
  ];

  const encoder = new AbiCoder();
  const data1 = encoder.encode(
    [
      "address",
      "address",
      "address",
      "address",
      "address",
      "address",
      "address",
      "address",
      "address"
    ],
    args1
  );
  const data2 = encoder.encode(["address", "address", "address", "address", "address"], args2);

  const instance = await QuickswapUSDCUSDT.deploy(data1, data2);
  await instance.deployed();
  console.log("QuickswapUSDCUSDT deployed to:", instance.address);
  await wait(20 * 1000); // wait for a minute

  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments: [data1, data2]
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
