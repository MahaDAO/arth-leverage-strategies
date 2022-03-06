import hre, { ethers } from "hardhat";
// const hre = require("hardhat");

async function main() {
  const constructorArguments = [""];

  // // We get the contract to deploy
  // const ArthUSDWrapper = await ethers.getContractFactory("WMasterChef");
  // const instance = await ArthUSDWrapper.deploy(
  //   String(constructorArguments[0]),
  //   String(constructorArguments[1]),
  //   String(constructorArguments[2]),
  //   String(constructorArguments[3]),
  //   String(constructorArguments[4]),
  //   constructorArguments[5]
  // );

  // await instance.deployed();
  // console.log("ArthUSDWrapper deployed to:", instance.address);

  await hre.run("verify:verify", {
    address: "0x0c42bDD350CC75D1AE475a015827eCb780ef1173",
    contract: "contracts/proxy/DSProxy.sol:DSProxy",
    constructorArguments: ["0x9e6e816dcd5d9466f4082713945c3645a31ada83"],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
