import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const WMaticExposure = await ethers.getContractFactory("WMaticExposure");
  const factory = await WMaticExposure.deploy(
    "0x9A9c25D9e304ddb284e5a36bE0cdEE0a58Ac3C04", // address _flashloan,
    "0xe52509181feb30eb4979e29ec70d50fd5c44d590", // address _arth,
    "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // address _wmatic,
    "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // address _usdc,
    "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", // address _uniswapRouter,
    "0x87FfC8AD29A87bD4a5F1927b0f8991b18dED8787", // address _borrowerOperations
    "0x8544A3d48e0821FA3891816BAd2a4095bb52a1C1", // address _controller
    "0x3EFf2CD823e6e9E220F60f83BF45e179fA0A831E", // address _proxyRegistry
    "0x8C021C5a2910D1812542D5495E4Fbf6a6c33Cb4f" // address _troveManager
  );

  await factory.deployed();
  console.log("WMaticExposure deployed to:", factory.address);

  await wait(60 * 1000); // wait for a minute

  await hre.run("verify:verify", {
    address: factory.address,
    constructorArguments: [
      "0x9A9c25D9e304ddb284e5a36bE0cdEE0a58Ac3C04", // address _flashloan,
      "0xe52509181feb30eb4979e29ec70d50fd5c44d590", // address _arth,
      "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270", // address _wmatic,
      "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // address _usdc,
      "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", // address _uniswapRouter,
      "0x87FfC8AD29A87bD4a5F1927b0f8991b18dED8787", // address _borrowerOperations
      "0x8544A3d48e0821FA3891816BAd2a4095bb52a1C1", // address _controller
      "0x3EFf2CD823e6e9E220F60f83BF45e179fA0A831E", // address _proxyRegistry
      "0x8C021C5a2910D1812542D5495E4Fbf6a6c33Cb4f" // address _troveManager
    ]
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
