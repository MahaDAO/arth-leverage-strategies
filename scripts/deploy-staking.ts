import hre, { ethers } from "hardhat";
// const hre = require("hardhat");

async function main() {
  const constructorArguments = [
    "0xe595b22beb0deee5a41d2b29a86e4edec8b7d180", // address _rewardsDistribution,
    "0x82b9b6ddd709f48119d979795e9f4379870db437", // address _rewardsToken,
    "0x3c9ce572eED9e205A1cdc5E2ead3DbCeD381030E", // address _stakingToken,
    "2592000" // uint256 _rewardsDuration
  ];

  // We get the contract to deploy
  const ArthUSDWrapper = await ethers.getContractFactory("StakingRewardsV2");
  const instance = await ArthUSDWrapper.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2]),
    String(constructorArguments[3])
  );

  await instance.deployed();
  console.log("StakingRewardsV2 deployed to:", instance.address);

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
