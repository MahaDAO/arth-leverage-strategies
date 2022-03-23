import { ethers } from "hardhat";
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "LPExpsoure",
    "0x44D05CBe676FEd4946DBA659C6a9bCC1A9835b7A"
  );

  // await registerStrategy(instance.address, "0xc377A2e1EE61Dd1A1e4512De3Bf813477691A008");
  // await wait(10 * 1000);

  const tx = await instance.closePosition(["700000000000000000000", "700000000000000000000"]);
  console.log("close", tx.hash);
}

const registerStrategy = async (strategy: string, acct: string) => {
  const account = await ethers.getContractAt("LeverageAccount", acct);

  // call the transfer fn on behalf of the account
  const tx = await account.approveStrategy(strategy);
  console.log("registerStrategy", tx.hash);
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
