import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";
import { deployOrLoadAndVerify } from "../utils";
import * as config from "./constants";

async function main() {
    console.log(`Deploying to ${network.name}...`);

    const e18 = BigNumber.from(10).pow(18);

    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address is ${deployer.address}.`);

    console.log("Deploying ETHTroveLogic...");
    const ETHTroveLogic = await deployOrLoadAndVerify("ETHTroveLogic", "ETHTroveLogic", []);

    console.log("Deploying ETHTroveStrategy...");
    const factory = await ethers.getContractFactory("ETHTroveStrategy", {
        libraries: {
            ETHTroveLogic: ETHTroveLogic.address
        }
    });

    const newImpl = await deployOrLoadAndVerify("ETHTroveLPImplV2", "ETHTroveStrategy", [], 5000, {
        ETHTroveLogic: ETHTroveLogic.address
    });

    // deploy as proxy
    console.log("Updating proxy...");
    const initDecode = factory.interface.encodeFunctionData("initialize", [
        config.borrowerOperationsAddr, // address _borrowerOperations,
        config.arthAddr, // address __arth,
        config.mahaAddr, // address __maha,
        config.priceFeed, // address _priceFeed,
        config.lendingPool, // address _pool,
        86400 * 30, // uint256 _rewardsDuration,
        deployer.address, // address _owner,
        config.treasury, // address _treasury,
        e18.mul(250).div(100) // uint256 _minCr 250%
    ]);

    console.log("new implementation", newImpl.address);
    console.log("init code", initDecode);
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
