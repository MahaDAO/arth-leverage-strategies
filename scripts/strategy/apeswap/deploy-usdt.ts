import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../utils";

async function main() {
  console.log("deploying ApeSwapExposure");

  // We get the contract to deploy
  const QuickSwapExposure = await ethers.getContractFactory("ApeSwapExposureUSDT");
  const instance = await QuickSwapExposure.deploy(
    "0x91aBAa2ae79220f68C0C76Dd558248BA788A71cD", // address _flashloan,
    "0xb69a424df8c737a122d0e60695382b3eec07ff4b", // address _arth,
    "0x55d398326f99059ff775485246999027b3197955", // address _usdt,
    "0xe9e7cea3dedca5984780bafc599bd69add087d56", // address _busd,
    "0x603c7f932ed1fc6575303d8fb018fdcbb0f39a95", // address _rewardToken,
    "0x16f3022DD080FeCDf0C02D4F793838f7a698599a", // address _ellipsis,
    "0x88fd584df3f97c64843cd474bdc6f78e398394f4", // address _arthUsd,
    "0xcf0febd3f17cef5b47b0cd257acf6025c5bff3b7" // address _uniswapRouter
  );

  await instance.deployed();
  console.log("ApeSwapExposure deployed to:", instance.address);

  await instance.init(
    "0xE4E773433Be8cc3ABDa9Bb5393C97336F27AE76b", // address _borrowerOperations,
    "0x7A535496c5a0eF6A9B014A01e1aB9d7493F503ea", // address _troveManager,
    "0xD23d824A9938DC490075CeAc311820312267A517", // address _priceFeed,
    "0xc5FB6476a6518dd35687e0Ad2670CB8Ab5a0D4C5", // address _stakingWrapper,
    "0x3A076D0EBF9ff41473071864bf23Afdbd77A253E" // address _accountRegistry
  );

  console.log("done init");

  await wait(20 * 1000); // wait for a minute

  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments: [
      "0x91aBAa2ae79220f68C0C76Dd558248BA788A71cD", // address _flashloan,
      "0xb69a424df8c737a122d0e60695382b3eec07ff4b", // address _arth,
      "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d", // address _usdc,
      "0xe9e7cea3dedca5984780bafc599bd69add087d56", // address _busd,
      "0x603c7f932ed1fc6575303d8fb018fdcbb0f39a95", // address _rewardToken,
      "0x16f3022DD080FeCDf0C02D4F793838f7a698599a", // address _ellipsis,
      "0x88fd584df3f97c64843cd474bdc6f78e398394f4", // address _arthUsd,
      "0xcf0febd3f17cef5b47b0cd257acf6025c5bff3b7" // address _uniswapRouter
    ]
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
