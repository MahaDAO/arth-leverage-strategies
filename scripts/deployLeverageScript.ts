import hre, { ethers } from "hardhat";

async function main() {
  const { provider } = ethers;

  const estimateGasPrice = await provider.getGasPrice();
  const gasPrice = estimateGasPrice.mul(3).div(2);
  console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, "gwei")} gwei`);

  const factory = await ethers.getContractFactory("FlashLoanLeverage");
  const instance = await factory.deploy(
    "0xd0d2DBdb27598fb2214bD6FB270560046A2Ff9A4",
    "0x36a669C9CF3e225c5F73efe065074f7D88a69fd8",
    [
      "0xd0d2DBdb27598fb2214bD6FB270560046A2Ff9A4",
      "0x36a669C9CF3e225c5F73efe065074f7D88a69fd8",
    ],
    "0xcFC5E66C35cE267f2d030D626270064a1342F058",
    "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    "0x63814A7Fb47Bff8288A2dDbA401D0127B5d49A49"
  );
  console.log("Instance deployed at address", instance.address);
  await hre.run("verify:verify", {
    address: instance.address,
    constructorArguments: [
      "0xd0d2DBdb27598fb2214bD6FB270560046A2Ff9A4",
      "0x36a669C9CF3e225c5F73efe065074f7D88a69fd8",
      [
        "0xd0d2DBdb27598fb2214bD6FB270560046A2Ff9A4",
        "0x36a669C9CF3e225c5F73efe065074f7D88a69fd8",
      ],
      "0xcFC5E66C35cE267f2d030D626270064a1342F058",
      "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
      "0x63814A7Fb47Bff8288A2dDbA401D0127B5d49A49",
    ],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
