import hre, { ethers } from "hardhat";
// const hre = require("hardhat");

async function main() {
  const constructorArguments = [
    "0xecce08c2636820a81fc0c805dbdc7d846636bbc4", // address _rewardsDistribution,
    "0xce86f7fcd3b40791f63b86c3ea3b8b355ce2685b", // address _rewardsToken,
    "0x84020eefe28647056eac16cb16095da2ccf25665", // address _stakingToken,
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
