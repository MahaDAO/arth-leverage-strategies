import { toUtf8CodePoints } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7", // address _chainlink,
    "0xBe5514E856a4eb971653BcC74475B26b56763FD0", // address _gmuOracle,
    "0x2791bca1f2de4661ed88a30c99a7a9449aa84174" // address _token
  ];

  // We get the contract to deploy
  const ChainlinkLPOracle = await ethers.getContractFactory("ChainlinkTokenOracleGMU");
  const instance = await ChainlinkLPOracle.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2])
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
