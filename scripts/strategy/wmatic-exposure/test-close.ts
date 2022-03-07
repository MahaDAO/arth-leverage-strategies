import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "WMaticExposure",
    "0x2A7128B2b8fd8E025E4260925A0Ca79F0b54021e"
  );

  // await approve("3000000000000000000000", instance.address);

  const tx = await instance.closePosition("300000000000000000000");
  console.log("open", tx.hash);
}

// const approve = async (amount: string, whom: string) => {
//   const account = await ethers.getContractAt(
//     "LeverageAccount",
//     "0x1CdEFF7E00EF19b99Fa84F4C7311361D7FFDf899"
//   );

//   const erc20 = await ethers.getContractFactory("ERC20");
//   const iface = erc20.interface;
//   const data = iface.encodeFunctionData("approve", [whom, amount]);

//   // call the transfer fn on behalf of the account
//   const tx = await account.callFn("0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270", data);
//   console.log("approve", tx.hash);
// };

const approve = async (amount: string, whom: string) => {
  const erc20 = await ethers.getContractAt("ERC20", "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270");
  const tx = await erc20.approve(whom, amount);
  console.log("approve", tx.hash);
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
