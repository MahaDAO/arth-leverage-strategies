import { BigNumber } from "ethers";
import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const precision = BigNumber.from(10).pow(9);

  const constructorArguments = [
    "0xFB82E32BcD4D72f0688f16109193053d52A23E47", // address _oracle,
    86400, // uint256 _epoch,
    precision.mul(5).toString() // uint256 _maxPriceChange
  ];

  // We get the contract to deploy
  const ChainlinkLPOracle = await ethers.getContractFactory("TWAPOracle");
  const instance = await ChainlinkLPOracle.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2])
  );

  await instance.deployed();
  console.log("TWAPOracle deployed to:", instance.address);
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
