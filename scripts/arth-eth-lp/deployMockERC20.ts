/* eslint-disable */

import hre, { ethers } from "hardhat";

import { wait } from "../utils";

async function main() {
  // We get the contract to deploy
  const MockERC20Factory = await ethers.getContractFactory("MockERC20");

  const instance = await MockERC20Factory.deploy("MahaDAO", "MAHA", "18");
  await instance.deployed();
  console.log("MAHA deployed to:", instance.address);

  await wait(60 * 1000); // wait for a minute

  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments: ["ARTH", "ARTH", "18"]
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
