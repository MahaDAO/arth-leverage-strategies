import { ethers } from "hardhat";

async function main() {
  const [owner] = await ethers.getSigners();

  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "CurveARTHRouter",
    "0xe5CBA8103594b98633d20F75264dd88EB8F64b30"
  );

  // await approve(
  //   "0xb69a424df8c737a122d0e60695382b3eec07ff4b", // arth
  //   "3000000000000000000000000",
  //   instance.address
  // );

  // await approve(
  //   "0xe9e7cea3dedca5984780bafc599bd69add087d56", // dai
  //   "3000000000000000000000000",
  //   instance.address
  // );
  await approve(
    "0x2791bca1f2de4661ed88a30c99a7a9449aa84174", // usdc
    "3000000000000000000000000",
    instance.address
  );
  // await approve(
  //   "0x55d398326f99059ff775485246999027b3197955", // usdt
  //   "3000000000000000000000000",
  //   instance.address
  // );

  // await approve(
  //   "0xb38b49bae104bbb6a82640094fd61b341a858f78",
  //   "3000000000000000000000000",
  //   instance.address
  // );

  console.log("i am", owner.address);

  // console.log("swapping 2 arth for 1 usdt and 3 busd");
  // const tx = await instance.sellARTHForExact(
  //   "200000000000000000", // uint256 amountArthInMax,
  //   "100000000000000000", // uint256 amountBUSDOut,
  //   "100000000000000000", // uint256 amountUSDCOut,
  //   "100000000000000000", // uint256 amountUSDTOut,
  //   owner.address, // address to,
  //   Math.floor(Date.now() / 1000) + 3600 // uint256 deadline
  // );
  // console.log("sell", tx.hash);

  console.log("swapping 1 usdc for 1 arth.usd");
  const tx2 = await instance.buyARTHForExact(
    "0", // uint256 amountDAIIn,
    "100000", // uint256 amountUSDCIn,
    "0", // uint256 amountUSDTIn,
    "40000", // uint256 amountARTHOutMin,
    owner.address, // address to,
    Math.floor(Date.now() / 1000) + 3600 // uint256 deadline
  );
  console.log("buy", tx2.hash);
}

// eslint-disable-next-line no-unused-vars
const approve = async (addr: string, amount: string, whom: string) => {
  const erc20 = await ethers.getContractAt("ERC20", addr);
  const tx = await erc20.approve(whom, amount);
  console.log("approve", addr, tx.hash);
  await tx.wait(2);
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
