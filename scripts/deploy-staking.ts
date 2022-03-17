import hre, { ethers } from "hardhat";
// const hre = require("hardhat");

async function main() {
  const constructorArguments = [
    "0xecce08c2636820a81fc0c805dbdc7d846636bbc4", // address _rewardsDistribution,
    "0xCE86F7fcD3B40791F63B86C3ea3B8B355Ce2685b", // address _rewardsToken,
    "0xb38b49bae104bbb6a82640094fd61b341a858f78", // address _stakingToken,
    "2592000" // uint256 _rewardsDuration
  ];

  // We get the contract to deploy
  // const ArthUSDWrapper = await ethers.getContractFactory("StakingRewardsV2");
  // const instance = await ArthUSDWrapper.deploy(
  //   String(constructorArguments[0]),
  //   String(constructorArguments[1]),
  //   String(constructorArguments[2]),
  //   String(constructorArguments[3])
  // );

  // await instance.deployed();
  // console.log("StakingRewardsV2 deployed to:", instance.address);

  await hre.run("verify:verify", {
    address: "0x6398C73761a802a7Db8f6418Ef0a299301bC1Fb0",
    constructorArguments
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
