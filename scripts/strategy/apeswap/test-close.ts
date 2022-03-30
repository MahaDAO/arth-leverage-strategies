import { ethers } from "hardhat";
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "ApeSwapExposure",
    "0x41969F40588C04b55fba4024f10045C6C1CB94C5"
  );

  await registerStrategy(instance.address, "0xC442C29B7Cf9C6C09Fc821B8a4ebB85b6d40fAA0");

  const tx = await instance.closePosition(
    ["90000000000000000000", "0"] // uint256 minExpectedCollateral,
  );

  console.log("close", tx.hash);
}

const registerStrategy = async (strategy: string, acct: string) => {
  const account = await ethers.getContractAt("LeverageAccount", acct);

  // call the transfer fn on behalf of the account
  const tx = await account.approveStrategy(strategy);
  console.log("registerStrategy", tx.hash);
  await tx.wait(1);
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
