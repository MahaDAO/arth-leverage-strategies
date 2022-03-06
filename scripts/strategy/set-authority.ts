import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "DSProxy",
    "0x0c42bDD350CC75D1AE475a015827eCb780ef1173"
  );
  const tx = await instance.setAuthority("0xb72d99Edf6ff016e1B4F2516c384c5904a6CeEC2");
  console.log(tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
