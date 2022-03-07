import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "WMaticExposure",
    "0x5Dd8649DE33cBC159965823dC3CB5A32C010F028"
  );

  const tx = await instance.closePosition("500000000000000000000");
  console.log("close", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
