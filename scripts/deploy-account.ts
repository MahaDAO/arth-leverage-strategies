import hre, { ethers } from "hardhat";
import { wait } from "./utils";

async function main() {
  // We get the contract to deploy
  const LeverageAccountFactory = await ethers.getContractFactory("LeverageAccountFactory");
  const factory = await LeverageAccountFactory.deploy();

  await factory.deployed();
  console.log("LeverageAccountFactory deployed to:", factory.address);

  const LeverageAccountRegistry = await ethers.getContractFactory("LeverageAccountRegistry");
  const registry = await LeverageAccountRegistry.deploy(factory.address);

  await registry.deployed();
  console.log("LeverageAccountRegistry deployed to:", registry.address);

  await wait(60 * 1000); // wait for a minute

  await hre.run("verify:verify", {
    address: registry.address,
    constructorArguments: [factory.address]
  });
  await hre.run("verify:verify", { address: factory.address });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
