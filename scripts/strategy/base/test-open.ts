import { ethers } from "hardhat";
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "BaseStrategy",
    "0xD24eaF5A7D8881265861800F93beAd2D0ad0aAA6"
  );

  const tx = await instance.run();
  console.log("tx", tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
