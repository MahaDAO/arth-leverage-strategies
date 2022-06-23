import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "0xB15bb89ed07D2949dfee504523a6A12F90117d18", // address _zap,
    "0xc5c71accca3a1357985e8912e1ed0aa910c30bdc", // address _lp,
    "0xAF6b98B5Dc17f4A9a5199545A1c29eE427266Da4", // address _pool,
    "0x85daB10c3BA20148cA60C2eb955e1F8ffE9eAa79", // address _arth,
    "0x8b02998366f7437f6c4138f4b543ea5c000cd608", // address _arthUsd,
    "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", // address _usdc,
    "0x55d398326f99059ff775485246999027b3197955", // address _usdt,
    "0xe9e7cea3dedca5984780bafc599bd69add087d56", // address _busd,
    "0x5b5bD8913D766D005859CE002533D4838B0Ebbb5" // address _pool3eps
  ];

  // We get the contract to deploy
  const EllipsisARTHRouter = await ethers.getContractFactory("EllipsisARTHRouter");
  const instance = await EllipsisARTHRouter.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2]),
    String(constructorArguments[3]),
    String(constructorArguments[4]),
    String(constructorArguments[5]),
    String(constructorArguments[6]),
    String(constructorArguments[7]),
    String(constructorArguments[8])
  );

  await instance.deployed();
  console.log("EllipsisARTHRouter deployed to:", instance.address);

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
