import { toUtf8CodePoints } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";
import { wait } from "./utils";

async function main() {
  const constructorArguments = [
    "0x51597f405303c4377e36123cbc172b13269ea163", // address _tokenAoracle,
    "0xcBb98864Ef56E9042e7d2efef76141f15731B82f", // address _tokenBoracle,
    "0xdD465B9c68750a02c307744a749954B1F9787efb", // address _gmuOracle,
    "0xc087c78abac4a0e900a327444193dbf9ba69058e" // address _lp
  ];

  // We get the contract to deploy
  const ChainlinkLPOracle = await ethers.getContractFactory("ChainlinkLPOracle");
  const instance = await ChainlinkLPOracle.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2]),
    String(constructorArguments[3])
  );

  await instance.deployed();
  console.log("ChainlinkLPOracle deployed to:", instance.address);
  await wait(15 * 1000);

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
