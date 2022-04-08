import { ethers } from "hardhat";
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "ApeSwapExposureUSDC",
    "0xF43E1F6e481F3602C786F3f9f60935F5C384dB11"
  );

  console.log(await instance.rewardsEarned("0xed77fd3f36535f26a072866ffead3db19bde9378"));
  // // await registerStrategy(instance.address, "0xC442C29B7Cf9C6C09Fc821B8a4ebB85b6d40fAA0");
  // // await approve(
  // //   "0xe9e7cea3dedca5984780bafc599bd69add087d56", // busd
  // //   "3000000000000000000000000",
  // //   instance.address
  // // );

  // const tx = await instance.openPosition(
  //   ["110000000000000000000", "110000000000000000000"], // uint256 finalExposure,
  //   ["100000000000000000000", "0"], // uint256 principalCollateral,
  //   0,
  //   10
  // );

  // // console.log(tx);
  // console.log("open", tx.hash);
}

const registerStrategy = async (strategy: string, acct: string) => {
  const account = await ethers.getContractAt("LeverageAccount", acct);

  // call the transfer fn on behalf of the account
  const tx = await account.approveStrategy(strategy);
  console.log("registerStrategy", tx.hash);
  await tx.wait(1);
};

const approve = async (addr: string, amount: string, whom: string) => {
  const erc20 = await ethers.getContractAt("ERC20", addr);
  const tx = await erc20.approve(whom, amount);
  console.log("approve", addr, tx.hash);
  await tx.wait(3);
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
