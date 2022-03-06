import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "WMaticExposure",
    "0xe2dB63E09009cEBE290D27C4757CEe320647c6F7"
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
