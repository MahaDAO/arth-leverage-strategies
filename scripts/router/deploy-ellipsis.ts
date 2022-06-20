import Web3 from "web3";

async function main() {
  const web3 = new Web3("https://bsc-dataseed.binance.org/");
  console.log(web3);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
