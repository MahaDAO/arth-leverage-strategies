import hre, { ethers } from "hardhat";
import { wait } from "./utils";

async function main() {
  // We get the contract to deploy
  const DSProxyFactory = await ethers.getContractFactory("DSProxyFactory");
  const instance = await DSProxyFactory.deploy();

  await instance.deployed();
  console.log("DSProxyFactory deployed to:", instance.address);

  await wait(60 * 1000); // wait for a minute

  await hre.run("verify:verify", { address: instance.address });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
