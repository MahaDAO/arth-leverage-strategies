import hre, { ethers } from "hardhat";
// eslint-disable-next-line node/no-missing-import
import { wait } from "../../utils";

async function main() {
  // We get the contract to deploy
  const LPExpsoure = await ethers.getContractFactory("LPExpsoure");
  const instance = await LPExpsoure.deploy(
    "0x7b009aE84341d1C1B64eFEceE2d41273E146dBE6", // address _flashloan,
    "0x8BFE2131a7Cb2072269f53624fd38EaCA6543309", // address _arth,
    "0x3467D9Fea78e9D82728aa6C3011F881ad7300a1e", // address _maha,
    "0x54406a69B4c629E4d5711140Faec3221672c71A1", // address _dai,
    "0x8954afa98594b838bda56fe4c12a09d7739d179b", // address _uniswapRouter,
    "0x682D628626136B0D245B71a585E32AEb922D4C1b", // address _borrowerOperations
    "0x90054AB3305E2ab1b6Bd48a9E2F5Ef261b2307f9", // address _wrapper
    "0xaeE4127Ed43654E57b73cbfDC81d35BB3B8De65A", // address _proxyRegistry
    "0xb6310276fD430CF2d19B182cCf95407463C8c484" // address _troveManager
  );

  await instance.deployed();
  console.log("LPExpsoure deployed to:", instance.address);

  await wait(60 * 1000); // wait for a minute

  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments: [
      "0x7b009aE84341d1C1B64eFEceE2d41273E146dBE6", // address _flashloan,
      "0x8BFE2131a7Cb2072269f53624fd38EaCA6543309", // address _arth,
      "0x3467D9Fea78e9D82728aa6C3011F881ad7300a1e", // address _maha,
      "0x54406a69B4c629E4d5711140Faec3221672c71A1", // address _dai,
      "0x8954afa98594b838bda56fe4c12a09d7739d179b", // address _uniswapRouter,
      "0x682D628626136B0D245B71a585E32AEb922D4C1b", // address _borrowerOperations
      "0x90054AB3305E2ab1b6Bd48a9E2F5Ef261b2307f9", // address _wrapper
      "0xaeE4127Ed43654E57b73cbfDC81d35BB3B8De65A", // address _proxyRegistry
      "0xb6310276fD430CF2d19B182cCf95407463C8c484" // address _troveManager
    ]
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
