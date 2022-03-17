import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "3EPS Staked", // string memory _name,
    "3EPS-S", // string memory _symbol,

    "0xcce949de564fe60e7f96c85e55177f8b9e4cf61b", // address _chef,

    "0x1", // addresss _pid,
    "0xaf4de8e872131ae328ce21d909c74705d3aaf452", // address _lpToken
    "0x5d47baba0d66083c52009271faf3f50dcc01023c", // address _rewardToken

    "0x382e9f09ec39bd2b8ef6b962572e7715ecbcf4ea", // address _rewardDestination
    "15000000000", // uint256 _rewardFee
    "0x9a66fC7a20f21fB72d9f229984109246e9c9F4a5" // address _governance
  ];

  // We get the contract to deploy
  // const WEllipsis3EPS = await ethers.getContractFactory("WEllipsis3EPS");
  // const instance = await WEllipsis3EPS.deploy(
  //   String(constructorArguments[0]),
  //   String(constructorArguments[1]),
  //   String(constructorArguments[2]),
  //   String(constructorArguments[3]),
  //   String(constructorArguments[4]),
  //   String(constructorArguments[5]),
  //   String(constructorArguments[6]),
  //   String(constructorArguments[7]),
  //   String(constructorArguments[8])
  // );

  // await instance.deployed();
  // console.log("WEllipsis3EPS deployed to:", instance.address);

  await wait(60 * 1000);

  await hre.run("verify:verify", {
    address: "0x26Da98b819e2b095E568237811923a8f84aEcB9C",
    constructorArguments
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
