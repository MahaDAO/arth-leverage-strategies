import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "QuickswapUSDCUSDT",
    "0x51210D88d1Af5f7579b1b73f8758eD6c55461A6C"
  );

  await registerStrategy(instance.address, "0xf68491167500Bac6e513D03fF137F34Df4720bd6");
  await approve(
    "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // usdc
    "3000000000000000000000000",
    instance.address
  );

  const tx = await instance.estimateGas.openPosition(
    ["391770720", "391770720"], // uint256 finalExposure,
    ["261180480", "0"], // uint256 principalCollateral,
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
