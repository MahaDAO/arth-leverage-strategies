import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "BUSD-USDC Staked APE-LP", // string memory _name,
    "BUSDUSDC-APE-LP-S", // string memory _symbol,

    "0x5c8D727b265DBAfaba67E050f2f739cAeEB4A6F9", // address _chef,

    "8", // addresss _pid,
    "0xc087c78abac4a0e900a327444193dbf9ba69058e", // address _lpToken
    "0x603c7f932ed1fc6575303d8fb018fdcbb0f39a95", // address _rewardToken

    "0x382e9f09ec39bd2b8ef6b962572e7715ecbcf4ea", // address _rewardDestination
    "0", // uint256 _rewardFee - 0%
    "0x9a66fC7a20f21fB72d9f229984109246e9c9F4a5" // address _governance
  ];

  // We get the contract to deploy
  const WApeSwapV2 = await ethers.getContractFactory("WApeSwapV1");
  const instance = await WApeSwapV2.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2]),
    String(constructorArguments[3]),
    String(constructorArguments[4]),
    String(constructorArguments[5]),
    String(constructorArguments[6]),
    String(constructorArguments[7]),
    String(constructorArguments[8])
  );

  await instance.deployed();
  console.log("WApeSwapV1 deployed to:", instance.address);

  await wait(60 * 1000);

  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
