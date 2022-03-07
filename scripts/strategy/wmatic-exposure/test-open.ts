import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "WMaticExposure",
    "0x37bb6ABc4Be43f103489Cf61F202Ab87dD847E1F"
  );

  // await registerStrategy(instance.address, "0xa91b68401bd5c436fe23a3f594ccc78ac746091a");
  // await approve("300000000000000000000", instance.address);

  const tx = await instance.openPosition(
    "290000000000000000000", // uint256 flashloanAmount,
    "300000000000000000000", // uint256 principalCollateral,
    "700000000000000000000", // uint256 minExposure,
    "15000000000000000", // uint256 maxBorrowingFee,

    "0x88fe4D4Dc27523dA91Dd13b0ce45E742017E7DeE", // address upperHint,
    "0x88fe4D4Dc27523dA91Dd13b0ce45E742017E7DeE", // address lowerHint,
    "0x0000000000000000000000000000000000000000" // address frontEndTag
  );
  console.log("open", tx.hash);
}

const registerStrategy = async (strategy: string, acct: string) => {
  const account = await ethers.getContractAt("LeverageAccount", acct);

  // call the transfer fn on behalf of the account
  const tx = await account.approveStrategy(strategy);
  console.log("registerStrategy", tx.hash);
};

const approve = async (amount: string, whom: string) => {
  const erc20 = await ethers.getContractAt("ERC20", "0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270");
  const tx = await erc20.approve(whom, amount);
  console.log("approve", tx.hash);
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
