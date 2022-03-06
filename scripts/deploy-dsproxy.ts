import hre, { ethers } from "hardhat";
import { wait } from "./utils";

async function main() {
  // We get the contract to deploy
  // const DSProxyFactory = await ethers.getContractFactory("DSProxyFactory");
  // const factory = await DSProxyFactory.deploy();

  // await factory.deployed();
  // console.log("DSProxyFactory deployed to:", factory.address);

  // const DSProxyRegistry = await ethers.getContractFactory("DSProxyRegistry");
  // const registry = await DSProxyRegistry.deploy(
  //   "0x4f1dF69A95280b6bbedf89C5c7a9CFA712B995F9"
  // );

  // await registry.deployed();
  // console.log("DSProxyRegistry deployed to:", registry.address);

  // await wait(60 * 1000); // wait for a minute

  await hre.run("verify:verify", {
    address: "0xb16fffa9e6f6489a2f8d77418eae58458efeff88",
    constructorArguments: ["0x4f1dF69A95280b6bbedf89C5c7a9CFA712B995F9"]
  });
  // await hre.run("verify:verify", { address: factory.address });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
