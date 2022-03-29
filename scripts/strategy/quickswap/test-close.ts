import { ethers } from "hardhat";
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "QuickSwapExposure",
    "0xFfEC018583152aB5f056c5323f1f68b701bF1Bc5"
  );

  await registerStrategy(instance.address, "0xFc74c53c1d31d30ca685DE93feDD2FB1BB3DA440");
  // await approve(
  //   "0x2791bca1f2de4661ed88a30c99a7a9449aa84174",
  //   "3000000000000000000000000",
  //   instance.address
  // );

  const tx = await instance.closePosition(
    ["0", "0"] // uint256 minExpectedCollateral,
  );

  // console.log(tx);
  console.log("open", tx.hash);
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
