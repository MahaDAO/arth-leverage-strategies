import hre, { ethers } from "hardhat";
import { wait } from "../utils";

async function main() {
  const constructorArguments = [
    "0x5035cc9988f88f99cdef210d833957a80236c0a4", // address _zap,
    "0x4CfAaBd5920021359BB22bB6924CCe708773b6AC", // address _lp,
    "0x1d4B4796853aEDA5Ab457644a18B703b6bA8b4aB", // address _pool,
    "0xB69A424Df8C737a122D0e60695382B3Eec07fF4B", // address _arth,
    "0x88fd584dF3f97c64843CD474bDC6F78e398394f4", // address _arthUsd,
    "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d", // address _usdc,
    "0x55d398326f99059fF775485246999027B3197955", // address _usdt,
    "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56" // address _busd
  ];

  // We get the contract to deploy
  const CurveSwapRouter = await ethers.getContractFactory("CurveSwapRouter");
  const instance = await CurveSwapRouter.deploy(
    String(constructorArguments[0]),
    String(constructorArguments[1]),
    String(constructorArguments[2]),
    String(constructorArguments[3]),
    String(constructorArguments[4]),
    String(constructorArguments[5]),
    String(constructorArguments[6]),
    String(constructorArguments[7])
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
