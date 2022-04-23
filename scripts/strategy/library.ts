import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../utils";

export async function initLibrary() {
  // deploy LeverageLibrary
  console.log("deploying LeverageLibrary");
  const leverageLibraryAddress = "0x8F2C23413A996b9f11cBB52BC8a4c69b3b14985f";
  const LeverageLibrary = await ethers.getContractFactory("LeverageLibrary");
  const leverageLibrary = leverageLibraryAddress
    ? await ethers.getContractAt("LeverageLibrary", leverageLibraryAddress)
    : await LeverageLibrary.deploy();
  console.log("LeverageLibrary at", leverageLibrary.address);
  leverageLibraryAddress == null && (await wait(15 * 1000)); // wait 15 sec

  // deploy TroveLibrary
  console.log("deploying TroveLibrary");
  const troveLibaryAddress = "0x621C066aB7da3a97453824854Fbd6682c79f0b7f";
  const TroveLibrary = await ethers.getContractFactory("TroveLibrary");
  const troveLibrary = troveLibaryAddress
    ? await ethers.getContractAt("TroveLibrary", troveLibaryAddress)
    : await TroveLibrary.deploy();
  console.log("TroveLibrary at", troveLibrary.address);

  if (!leverageLibraryAddress) {
    await wait(15 * 1000);
    await hre.run("verify:verify", {
      address: leverageLibrary.address
    });
  }

  if (!troveLibaryAddress) {
    await wait(15 * 1000);
    await hre.run("verify:verify", {
      address: troveLibrary.address
    });
  }

  return {
    troveLibrary,
    leverageLibrary
  };
}
