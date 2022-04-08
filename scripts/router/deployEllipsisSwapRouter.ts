import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "0x5ab5c56b9db92ba45a0b46a207286cd83c15c939", // address _ellipsisSwap,
    "0xdde5fdb48b2ec6bc26bb4487f8e3a4eb99b3d633", // address _lp,
    "0xdde5fdb48b2ec6bc26bb4487f8e3a4eb99b3d633", // address _pool,
    "0xe52509181feb30eb4979e29ec70d50fd5c44d590", // address _arth,
    "0x84f168e646d31f6c33fdbf284d9037f59603aa28", // address _arthUsd,
    "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // address _usdc,
    "0xc2132d05d31c914a87c6611c10748aeb04b58e8f", // address _usdt,
    "0x8f3cf7ad23cd3cadbd9735aff958023239c6a063" // address _busd
  ];

  // We get the contract to deploy
  const CurveSwapRouter = await ethers.getContractFactory("CurveSwapRouter");
  const instance = await CurveSwapRouter.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2]),
    String(constructorArguments[3]),
    String(constructorArguments[4]),
    String(constructorArguments[5]),
    String(constructorArguments[6]),
    String(constructorArguments[7])
  );

  await instance.deployed();
  console.log("EllipsisARTHRouter deployed to:", instance.address);

  await wait(30 * 1000);

  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
