import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "Staked QuickSwap USDT-USDC LP", // string memory _name,
    "USDCUSDT-QLP-S", // string memory _symbol,

    "0xafb76771c98351aa7fca13b130c9972181612b54", // address _staking,
    "0x2cf7252e74036d1da831d11089d326296e64a728", // addresss _underlying,
    "0xf28164A485B0B2C90639E47b0f377b4a438a16B1", // address _reward

    "0xc4e65254bb14dd5a99259247b0b9760722dc2a7f", // address _rewardDestination
    "0xa1bc5163FADAbE25880897C95d3701ed388A2AA0", // address _governance
  ];

  // We get the contract to deploy
  const WStakingRewards = await ethers.getContractFactory("WStakingRewards");
  const instance = await WStakingRewards.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2]),
    String(constructorArguments[3]),
    String(constructorArguments[4]),
    String(constructorArguments[5]),
    String(constructorArguments[6])
  );

  await instance.deployed();
  console.log("WStakingRewards deployed to:", instance.address);

  await wait(60 * 1000);

  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments,
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
