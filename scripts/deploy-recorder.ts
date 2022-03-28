import hre, { ethers } from "hardhat";
import { wait } from "./utils";

async function main() {
  // We get the contract to deploy
  const PrincipalCollateralRecorder = await ethers.getContractFactory("PrincipalCollateralRecorder");
  const recorder = await PrincipalCollateralRecorder.deploy();

  await recorder.deployed();
  console.log("LeverageAccountFactory deployed to:", recorder.address);

  await wait(30 * 1000); // wait for a minute
  await hre.run("verify:verify", { address: recorder.address });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
