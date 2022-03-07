import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const registry = await ethers.getContractAt(
    "LeverageAccountRegistry",
    "0x3EFf2CD823e6e9E220F60f83BF45e179fA0A831E"
  );

  const tx = await registry["build()"]();
  console.log(tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
