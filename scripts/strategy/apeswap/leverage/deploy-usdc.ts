import { AbiCoder } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../../utils";
// eslint-disable-next-line node/no-missing-import
import { initLibrary } from "../../library";

async function main() {
  const { leverageLibrary, troveLibrary } = await initLibrary();

  console.log("deploying ApeSwapLeverageBUSDUSDC");

  // We get the contract to deploy
  const ApeSwapLeverageBUSDUSDC = await ethers.getContractFactory("ApeSwapBUSDUSDC", {
    libraries: {
      LeverageLibrary: leverageLibrary.address,
      TroveLibrary: troveLibrary.address
    }
  });

  const args1 = [
    "0x91aBAa2ae79220f68C0C76Dd558248BA788A71cD", // address _flashloan,
    "0xb69a424df8c737a122d0e60695382b3eec07ff4b", // address _arth,
    "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", // address _usdc,
    "0xe9e7cea3dedca5984780bafc599bd69add087d56", // address _busd,
    "0x603c7f932ed1fc6575303d8fb018fdcbb0f39a95", // address _rewardToken,
    "0x8659F81100eB3151bB8BE7e9c095d2df1C105E72", // address _ellipsis,
    "0x88fd584df3f97c64843cd474bdc6f78e398394f4", // address _arthUsd,
    "0xcf0febd3f17cef5b47b0cd257acf6025c5bff3b7" // address _uniswapRouter
  ];

  const args2 = [
    "0xC1105fb83355596E3eC54588A87747391bBdc92e", // address _borrowerOperations,
    "0xa920823d7F7Fc33222DF17E475567438B1e7F84c", // address _troveManager,
    "0x6852F8bB8a476fCAD8D6a54aF4a1A61B29146484", // address _priceFeed,
    "0xBb9858603B1FB9375f6Df972650343e985186Ac5", // address _stakingWrapper,
    "0x3A076D0EBF9ff41473071864bf23Afdbd77A253E" // address _accountRegistry
  ];

  const encoder = new AbiCoder();
  const data1 = encoder.encode(
    ["address", "address", "address", "address", "address", "address", "address", "address"],
    args1
  );
  const data2 = encoder.encode(["address", "address", "address", "address", "address"], args2);

  const instance = await ApeSwapLeverageBUSDUSDC.deploy(data1, data2);
  await instance.deployed();
  console.log("ApeSwapLeverageBUSDUSDC deployed to:", instance.address);
  await wait(20 * 1000); // wait for a minute

  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments: [data1, data2]
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
