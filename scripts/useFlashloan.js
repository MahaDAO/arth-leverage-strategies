const { utils } = require('ethers');
const { network, ethers } = require('hardhat');
const Web3 = require('web3');
require('dotenv').config();

async function main() {
  const { provider } = ethers;
  const ZERO_ADDRESS = '0x' + '0'.repeat(40)
  const web3 = new Web3('https://matic-mumbai.chainstacklabs.com');
  const estimateGasPrice = await provider.getGasPrice();
  const gasPrice = estimateGasPrice.mul(10).div(2);
  console.log(`Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);

  const priceFeed = await ethers.getContractAt(
    "PriceFeed",
    "0xDB4137BE32eCF5080897333a8AAEDE15e8bC87F2"
  );
  const collateral = await ethers.getContractAt(
    "LiquityLUSDToken",
    "0x36a669C9CF3e225c5F73efe065074f7D88a69fd8"
  );

  const arth = await ethers.getContractAt(
    "LiquityLUSDToken",
    "0xd0d2DBdb27598fb2214bD6FB270560046A2Ff9A4"
  );
  const script = await ethers.getContractAt(
    'FlashLoanLeverage',
    "0x0516fb086E556c2902F1fbAa5Ff5bBB539789C0B"
  );
  const flashloan = await ethers.getContractAt(
    "IFlashLoan",
    "0xcFC5E66C35cE267f2d030D626270064a1342F058"
  );

  await collateral.approve(
    "0x0516fb086E556c2902F1fbAa5Ff5bBB539789C0B",
    ethers.BigNumber.from(10).pow(18).mul(10e6).mul(10e3)
  );

  console.log(
    "Price",
    (await priceFeed.callStatic.fetchPrice()).toString()
  )
  const flashloanAmt = "872181762679342374951";
  const troveData = 
    web3.eth.abi.encodeParameters(
        ["uint256", "uint256", "uint256", "address", "address", "address"], 
        [
            ethers.BigNumber.from(10).pow(18),
            ethers.BigNumber.from('872181762679342374951').add(250),
            ethers.BigNumber.from(10).pow(18).mul(2794),
            ZERO_ADDRESS,
            ZERO_ADDRESS,
            ZERO_ADDRESS
        ]
    )

  const res = await flashloan.flashLoan(
    "0x0516fb086E556c2902F1fbAa5Ff5bBB539789C0B",
    flashloanAmt,
    troveData,
    {gasPrice}
  );

  console.log('Response hash', res.hash)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });