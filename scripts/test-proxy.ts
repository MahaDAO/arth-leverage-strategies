import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const proxy = await ethers.getContractAt("DSProxy", "0x0c42bDD350CC75D1AE475a015827eCb780ef1173");

  const erc20 = await ethers.getContractFactory("ERC20");
  const iface = erc20.interface;
  const data = iface.encodeFunctionData("approve", [
    "0xE595b22bEB0dEEE5a41D2B29a86E4eDeC8B7D180",
    "1"
  ]);

  console.log(data);
  const tx = await proxy["execute(address,bytes)"](
    "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
    data
  );
  console.log(tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
