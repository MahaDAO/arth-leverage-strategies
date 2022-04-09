import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../utils";

export async function initLibrary() {
  // deploy LeverageLibraryBSC
  console.log("deploying LeverageLibraryBSC");
  const leverageLibraryAddress = "0xb2514553b994BE2E9F0D3fF8E43DF9113E145616";
  const LeverageLibraryBSC = await ethers.getContractFactory("LeverageLibraryBSC");
  const leverageLibrary = leverageLibraryAddress
    ? await ethers.getContractAt("LeverageLibraryBSC", leverageLibraryAddress)
    : await LeverageLibraryBSC.deploy();
  console.log("LeverageLibraryBSC at", leverageLibrary.address);
  leverageLibraryAddress == null && (await wait(15 * 1000)); // wait 15 sec

  // deploy TroveLibrary
  console.log("deploying TroveLibrary");
  const troveLibaryAddress = "0x49A7Cc69A95F4beF8979657C86b05C0A5d2f32cE";
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
