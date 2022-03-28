import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "USDC-USDT Staked QLP", // string memory _name,
    "USDC-USDT-QLP-S", // string memory _symbol,

    "0xafb76771c98351aa7fca13b130c9972181612b54", // address _staking,
    "0x2cf7252e74036d1da831d11089d326296e64a728", // addresss _underlying,
    "0xf28164a485b0b2c90639e47b0f377b4a438a16b1", // address _reward

    "0x41ef0505ebaa70ec10f7b8ee8965e269a50ce3ee", // address _rewardDestination
    "5000000000", // address _rewardFeeRate = 5%

    "0xa1bc5163FADAbE25880897C95d3701ed388A2AA0" // address _governance
  ];

  // We get the contract to deploy
  // const WStakingRewards = await ethers.getContractFactory("WQuickswap");
  // const instance = await WStakingRewards.deploy(
  //   String(constructorArguments[0]),
  //   String(constructorArguments[1]),
  //   String(constructorArguments[2]),
  //   String(constructorArguments[3]),
  //   String(constructorArguments[4]),
  //   String(constructorArguments[5]),
  //   String(constructorArguments[6]),
  //   String(constructorArguments[7])
  // );

  // await instance.deployed();
  // console.log("WQuickswap deployed to:", instance.address);

  // await wait(60 * 1000);

  await hre.run("verify:verify", {
    address: "0x54A4A4F6EA24863bda03972e281F3fb864AD3EBc",
    constructorArguments
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
