import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "WMaticExposure",
    "0x9bf7c2E8143f53F3aD6966e99De70324c4624153"
  );

  // await approve("3000000000000000000000", instance.address);

  const tx = await instance.closePosition("500000000000000000000");
  console.log("close", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
