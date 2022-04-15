import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "0xfe4a8cc5b5b2366c1b58bea3858e81843581b2f7", // address _tokenAoracle,
    "0x0a6513e40db6eb1b165753ad52e80663aea50545", // address _tokenBoracle,
    "0xbe5514e856a4eb971653bcc74475b26b56763fd0", // address _gmuOracle,
    "0x2cf7252e74036d1da831d11089d326296e64a728" // address _lp
  ];

  // We get the contract to deploy
  const ChainlinkLPOracle = await ethers.getContractFactory("ChainlinkLPOracleGMU");
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
