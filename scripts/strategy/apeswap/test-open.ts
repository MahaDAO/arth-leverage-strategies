import { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "ApeSwapBUSDUSDC",
    "0x5C985f16657458d0F20B56af68F27eE149C9630B"
  );

  // console.log(await instance.rewardsEarned("0xed77fd3f36535f26a072866ffead3db19bde9378"));
  await registerStrategy(instance.address, "0xBbA13eb45ed9aA4C1648BCfB23FC883088A35CEc");
  await approve(
    "0xe9e7cea3dedca5984780bafc599bd69add087d56", // busd
    "3000000000000000000000000",
    instance.address
  );

  const tx = await instance.estimateGas.openPosition(
    ["40000000000000000000", "40000000000000000000"], // uint256 finalExposure,
    ["170000000000000000000", "0"], // uint256 principalCollateral,
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
