import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "0x5ab5C56B9db92Ba45a0B46a207286cD83C15C939", // address _zap,
    "0xdde5fdb48b2ec6bc26bb4487f8e3a4eb99b3d633", // address _lp,
    "0xdde5fdb48b2ec6bc26bb4487f8e3a4eb99b3d633", // address _pool,
    "0xe52509181feb30eb4979e29ec70d50fd5c44d590", // address _arth,
    "0x84f168e646d31F6c33fDbF284D9037f59603Aa28", // address _arthUsd,
    "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // address _usdc,
    "0xc2132d05d31c914a87c6611c10748aeb04b58e8f", // address _usdt,
    "0x8f3cf7ad23cd3cadbd9735aff958023239c6a063" // address _dai
  ];

  // We get the contract to deploy
  const CurveARTHRouter = await ethers.getContractFactory("CurveARTHRouter");
  const instance = await CurveARTHRouter.deploy(
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
  console.log("CurveARTHRouter deployed to:", instance.address);

  // await wait(30 * 1000);

  await hre.run("verify:verify", {
    address: "0xDAb00C06BeB054Ca21c9BEB801D2B482127B9325",
    constructorArguments
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
