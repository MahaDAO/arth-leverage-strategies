import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../utils";

export async function initLibrary() {
  // deploy LeverageLibrary
  console.log("deploying LeverageLibrary");
  const leverageLibraryAddress = "0x2ADd8472cC41dbee6c8E9af2C4a08a7256c5A088";
  const LeverageLibrary = await ethers.getContractFactory("LeverageLibrary");
  const leverageLibrary = leverageLibraryAddress
    ? await ethers.getContractAt("LeverageLibrary", leverageLibraryAddress)
    : await LeverageLibrary.deploy();
  console.log("LeverageLibrary at", leverageLibrary.address);
  leverageLibraryAddress == null && (await wait(15 * 1000)); // wait 15 sec

  // deploy TroveLibrary
  console.log("deploying TroveLibrary");
  const troveLibaryAddress = "0x00328839B044A8D60d2C07DFe2538E7dD12BB49C";
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
