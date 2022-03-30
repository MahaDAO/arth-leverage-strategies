import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "IStableSwap",
    "0x98245Bfbef4e3059535232D68821a58abB265C45"
  );

  // await approve(
  //   "0x88fd584df3f97c64843cd474bdc6f78e398394f4", // approve arth.usd
  //   "3000000000000000000000000",
  //   instance.address
  // );

  console.log("swapping 2 arth for 1 usdt and 3 busd");

  const underlying = await instance.get_dy_underlying("3", "0", "1000000");
  const newRate = underlying.mul(1010).div(1000);

  console.log(
    await (await instance.get_dy_underlying("3", "0", "10000000000000000000000")).toString(),
    await (await instance.get_dy_underlying("3", "0", "10000000000000000000000")).mul(3).toString(),
    await (await instance.get_dy_underlying("3", "0", "30000000000000000000000")).toString()
  );

  console.log(underlying.toString());
  console.log(newRate.toString());

  const tx = await instance.exchange_underlying(
    "0", // i: BigNumberish,
    "3", // j: BigNumberish,
    newRate, // dx: BigNumberish,
    "1000000", // min_dy: BigNumberish,
    "0xEd77FD3F36535F26A072866fFeAD3Db19bde9378"
  );

  console.log(await (await instance.get_dy_underlying("3", "0", "1000000")).toString());

  console.log("swap", tx.hash);
}

const approve = async (addr: string, amount: string, whom: string) => {
  const erc20 = await ethers.getContractAt("ERC20", addr);
  const tx = await erc20.approve(whom, amount);
  console.log("approve", addr, tx.hash);
  await tx.wait(3);
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});

// 29708159046998601393396
// 29628746063144330876854
