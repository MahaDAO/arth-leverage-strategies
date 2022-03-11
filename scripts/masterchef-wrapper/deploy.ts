import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "DAI-USDC Staked APE-LP", // string memory _name,
    "DAIUSDC-ALP-S", // string memory _symbol,

    "0x54aff400858Dcac39797a81894D9920f16972D1D", // address _chef,

    "0x5", // addresss _pid,
    "0x5b13B583D4317aB15186Ed660A1E4C65C10da659", // address _lpToken
    "0x5d47baba0d66083c52009271faf3f50dcc01023c", // address _rewardToken

    "0xc4e65254bb14dd5a99259247b0b9760722dc2a7f", // address _rewardDestination
    "0x0", // uint256 _rewardFee
    "0xa1bc5163FADAbE25880897C95d3701ed388A2AA0" // address _governance
  ];

  // We get the contract to deploy
  const WStakingRewards = await ethers.getContractFactory("WApeSwapV2");
  const instance = await WStakingRewards.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2]),
    String(constructorArguments[3]),
    String(constructorArguments[4]),
    String(constructorArguments[5]),
    String(constructorArguments[6]),
    String(constructorArguments[7]),
    String(constructorArguments[8])
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
