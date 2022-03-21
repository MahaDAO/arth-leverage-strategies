import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const BaseStrategy = await ethers.getContractFactory("BaseStrategy");
  const instance = await BaseStrategy.deploy(
    "0x8BFE2131a7Cb2072269f53624fd38EaCA6543309" // address _arth,
  );

  await instance.deployed();
  console.log("BaseStrategy deployed to:", instance.address);

  await wait(60 * 1000); // wait for a minute

  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments: ["0x8BFE2131a7Cb2072269f53624fd38EaCA6543309"]
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
