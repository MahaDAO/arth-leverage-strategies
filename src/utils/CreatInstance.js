const hardhatEthers = require('hardhat')
const ethers = require('ethers')

const TEST_MODE = process.env.PRODUCTION_MODE === "Test" ? true : false

const createContract = async(ABI, address, wallet) => {
    if (TEST_MODE) {
        return await hardhatEthers.ethers.getContractAt(ABI, address, wallet)
    } else {
        return new ethers.Contract(address, ABI, wallet);
    }
} 

module.exports = {
    ethers: TEST_MODE ? hardhatEthers.ethers : ethers.ethers,
    createContract
}