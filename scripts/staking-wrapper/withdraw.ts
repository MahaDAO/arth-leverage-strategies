import { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const [me] = await ethers.getSigners();

  const lpTokenAddress = "0x2cf7252e74036d1da831d11089d326296e64a728";
  const wrappedStakingContractAddress =
    "0xce7C04088B6AF2f4703f1D39405122368cFd4409";

  // // We get the contract to deploy
  // const WStakingRewards = await ethers.getContractFactory("WStakingRewards");
  const lpToken = await ethers.getContractAt("IERC20", lpTokenAddress);

  const wrappedStakingContract = await ethers.getContractAt(
    "WStakingRewards",
    wrappedStakingContractAddress
  );

  const lpBalance = await lpToken.balanceOf(me.address);
  const wBalance = await wrappedStakingContract.balanceOf(me.address);
  console.log("my wrapped balance is", wBalance.toString());

  console.log("i am", me.address);

  console.log("withdraw wrapped token with rewards");
  const tx = await wrappedStakingContract.withdraw(wBalance);
  console.log(tx.hash);

  await wait(10 * 1000); // wait 10s

  console.log("my lp balance is", lpBalance.toString());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
