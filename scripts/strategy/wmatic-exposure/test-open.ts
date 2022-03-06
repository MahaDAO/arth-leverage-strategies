import { ethers } from "hardhat";

async function main() {
  // We get the contract to deploy
  const instance = await ethers.getContractAt(
    "WMaticExposure",
    "0xE0aE4EfFd1aB84044602d68D8EBE227468798204"
  );

  const data = ethers.utils.defaultAbiCoder.encode(
    ["uint256", "uint256", "uint256", "uint256", "address", "address", "address"],
    [
      "100000",
      "15000000000000000",
      "250000000000000000000",
      "600000000000000000000",
      "0x88fe4D4Dc27523dA91Dd13b0ce45E742017E7DeE",
      "0x88fe4D4Dc27523dA91Dd13b0ce45E742017E7DeE",
      "0x0000000000000000000000000000000000000000"
    ]
  );
  const tx = await instance.openPosition(data);
  console.log(tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
