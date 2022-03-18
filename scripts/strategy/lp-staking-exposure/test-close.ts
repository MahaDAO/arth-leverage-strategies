import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "WMaticExposure",
    "0xAaA6a7A5d7eC7C7691576D557E1D2CDaBeca6C4A"
  );

  const tx = await instance.closePosition();
  console.log("close", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
