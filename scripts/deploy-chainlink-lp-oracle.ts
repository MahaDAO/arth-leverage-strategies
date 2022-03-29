import { toUtf8CodePoints } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";
import { wait } from "./utils";

async function main() {
  const constructorArguments = [
    "0xB97Ad0E74fa7d920791E90258A6E2085088b4320", // address _tokenAoracle,
    "0xcBb98864Ef56E9042e7d2efef76141f15731B82f", // address _tokenBoracle,
    "0xdD465B9c68750a02c307744a749954B1F9787efb", // address _gmuOracle,
    "0x2e707261d086687470b515b320478eb1c88d49bb" // address _lp
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
