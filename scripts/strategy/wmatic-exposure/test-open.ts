import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "WMaticExposure",
    "0xa52D6E8A9d3Ba41c6E1A42e9F89b0022E403E39f"
  );

  const data = ethers.utils.defaultAbiCoder.encode([""], []);
  console.log(data);
  instance.closePosition("100000");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
