import hre, { ethers } from "hardhat";
// const hre = require("hardhat");

async function main() {
  const constructorArguments = [
    "0xecce08c2636820a81fc0c805dbdc7d846636bbc4", // address _rewardsDistribution,
    "0xCE86F7fcD3B40791F63B86C3ea3B8B355Ce2685b", // address _rewardsToken,
    "0x4cfaabd5920021359bb22bb6924cce708773b6ac", // address _stakingToken,
    "2592000" // uint256 _rewardsDuration
  ];

  // We get the contract to deploy
  const StakingRewardsV2 = await ethers.getContractFactory("StakingRewardsV2");
  const instance = await StakingRewardsV2.deploy(
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
