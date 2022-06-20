import { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "ApeSwapBUSDUSDC",
    "0x33611cb8bb7776b4e312e969ea933a1e1b9f087b"
  );

  // await registerStrategy(instance.address, "0xBbA13eb45ed9aA4C1648BCfB23FC883088A35CEc");
  // await approve(
  //   "0xe9e7cea3dedca5984780bafc599bd69add087d56", // busd
  //   "3000000000000000000000000",
  //   instance.address
  // );

  const tx = await instance.openPosition(
    ["70000000000000000000", "70000000000000000000"], // uint256 finalExposure,
    ["100000000000000000000", "0"], // uint256 principalCollateral,
    0,
    0
  );

  console.log(tx);
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
