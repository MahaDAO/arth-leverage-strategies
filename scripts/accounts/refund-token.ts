import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const account = await ethers.getContractAt(
    "LeverageAccount",
    "0x1CdEFF7E00EF19b99Fa84F4C7311361D7FFDf899"
  );

  const erc20 = await ethers.getContractFactory("ERC20");
  const iface = erc20.interface;
  const data = iface.encodeFunctionData("transfer", [
    "0xbA1af27c0eFdfBE8B0FE1E8F890f9E896D1B2d6f",
    "1"
  ]);

  // call the transfer fn on behalf of the account
  const tx = await account.callFn("0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270", data);
  console.log(tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
