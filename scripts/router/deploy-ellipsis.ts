import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "0x5035cc9988f88f99cdef210d833957a80236c0a4", // address _zap,
    "0xb38b49bae104bbb6a82640094fd61b341a858f78", // address _lp,
    "0x98245Bfbef4e3059535232D68821a58abB265C45", // address _pool,
    "0xb69a424df8c737a122d0e60695382b3eec07ff4b", // address _arth,
    "0x88fd584df3f97c64843cd474bdc6f78e398394f4", // address _arthUsd,
    "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", // address _usdc,
    "0x55d398326f99059ff775485246999027b3197955", // address _usdt,
    "0xe9e7cea3dedca5984780bafc599bd69add087d56", // address _busd,
    "0x19EC9e3F7B21dd27598E7ad5aAe7dC0Db00A806d" // address _pool3eps
  ];

  // We get the contract to deploy
  const EllipsisARTHRouter = await ethers.getContractFactory("EllipsisARTHRouter");
  const instance = await EllipsisARTHRouter.deploy(
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
  console.log("EllipsisARTHRouter deployed to:", instance.address);

  await wait(30 * 1000);

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
