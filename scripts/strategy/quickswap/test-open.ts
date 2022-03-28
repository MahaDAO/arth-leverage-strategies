import { ethers } from "hardhat";
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "QuickSwapExposure",
    "0x54c96A9777F47CC3e7508258999C7cC7956A1977"
  );

  // await registerStrategy(instance.address, "0xa91b68401bd5c436fe23a3f594ccc78ac746091a");
  // await approve(
  //   "0xe52509181feb30eb4979e29ec70d50fd5c44d590",
  //   "3000000000000000000000000",
  //   instance.address
  // );
  // await wait(10 * 1000);

  const tx = await instance.test(
    "1000000000000000000", // uint256 borrowedCollateral,
    "100000000000000000",
    ["10000", "10000"]
  );

  // console.log(tx);
  console.log("open", tx.hash);
}

const registerStrategy = async (strategy: string, acct: string) => {
  const account = await ethers.getContractAt("LeverageAccount", acct);

  // call the transfer fn on behalf of the account
  const tx = await account.approveStrategy(strategy);
  console.log("registerStrategy", tx.hash);
};

const approve = async (addr: string, amount: string, whom: string) => {
  const erc20 = await ethers.getContractAt("ERC20", addr);
  const tx = await erc20.approve(whom, amount);
  console.log("approve", addr, tx.hash);
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
