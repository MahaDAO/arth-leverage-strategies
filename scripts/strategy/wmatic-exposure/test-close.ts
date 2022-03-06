import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "WMaticExposure",
    "0x9ffF134682cF437b88a2E66b54E94D9e5469fF35"
  );

  console.log(await instance.getProxy());
  const tx = await instance.closePosition2();
  console.log(tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
