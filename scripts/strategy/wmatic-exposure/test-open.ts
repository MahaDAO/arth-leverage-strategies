import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "WMaticExposure",
    "0xda672e23BD07f210E2e214B7460Cb9905b9B92c2"
  );

  // await approve("100000");

  const data = ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256", "uint256", "address", "address", "address"],
    [
      "100000", // uint256 flashloanAmount,
      "100000", // uint256 principalCollateral,
      "0", // uint256 minExposure,
      "0x88fe4D4Dc27523dA91Dd13b0ce45E742017E7DeE", // address upperHint,
      "0x88fe4D4Dc27523dA91Dd13b0ce45E742017E7DeE", // address lowerHint,
      "0x0000000000000000000000000000000000000000" // address frontEndTag
    ]
  );
  const tx = await instance.openPosition(data);
  console.log(tx.hash);
}

const approve = async (amount: string) => {
  const account = await ethers.getContractAt(
    "LeverageAccount",
    "0x1CdEFF7E00EF19b99Fa84F4C7311361D7FFDf899"
  );

  const erc20 = await ethers.getContractFactory("ERC20");
  const iface = erc20.interface;
  const data = iface.encodeFunctionData("approve", [
    "0xbA1af27c0eFdfBE8B0FE1E8F890f9E896D1B2d6f",
    amount
  ]);

  // call the transfer fn on behalf of the account
  const tx = await account.callFn("0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270", data);
  console.log("approve", tx.hash);
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
