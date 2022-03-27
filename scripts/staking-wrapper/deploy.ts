import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "BUSD-USDC Staked ALP", // string memory _name,
    "BUSD-USDC-ALP-S", // string memory _symbol,

    "0xa18bf6b7d39DA5F48683527ee1080F47fD50C6B5", // address _staking,
    "0x2e707261d086687470b515b320478eb1c88d49bb", // addresss _underlying,
    "0x82b9b6ddd709f48119d979795e9f4379870db437", // address _reward

    "0xE595b22bEB0dEEE5a41D2B29a86E4eDeC8B7D180", // address _rewardDestination
    "15000000000", // address _rewardFeeRate = 15%

    "0xE595b22bEB0dEEE5a41D2B29a86E4eDeC8B7D180" // address _governance
  ];

  // We get the contract to deploy
  const WStakingRewards = await ethers.getContractFactory("WQuickswap");
  const instance = await WStakingRewards.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2]),
    String(constructorArguments[3]),
    String(constructorArguments[4]),
    String(constructorArguments[5]),
    String(constructorArguments[6]),
    String(constructorArguments[7])
  );

  await instance.deployed();
  console.log("WStakingRewards deployed to:", instance.address);

  await wait(60 * 1000);

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
