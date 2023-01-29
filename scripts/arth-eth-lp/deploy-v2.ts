/* eslint-disable */

import { BigNumber } from "ethers";
import hre, { ethers, network } from "hardhat";
import { deployOrLoad, deployOrLoadAndVerify, getOutputAddress } from "../utils";
// eslint-disable-next-line node/no-missing-import
import * as config from "./constants";
// eslint-disable-next-line node/no-missing-import
import { reportBalances } from "./utils";

async function main() {
    console.log(`Deploying to ${network.name}...`);

    const e18 = BigNumber.from(10).pow(18);

    const [deployer] = await ethers.getSigners();
    console.log(`Deployer address is ${deployer.address}.`);

    const proxy = await ethers.getContractAt(
        "TransparentUpgradeableProxy",
        "0xA9735E594624339f8fbc8a99c57C13C7B4E8BCaC"
    );

    console.log("proxy admin", await proxy.callStatic.proxyAdmin());

    console.log("Deploying ETHTroveLogic...");
    const ETHTroveLogic = await deployOrLoadAndVerify("ETHTroveLogic", "ETHTroveLogic", []);

    console.log("Deploying ETHTroveStrategy...");
    const factory = await ethers.getContractFactory("ETHTroveStrategy", {
        libraries: {
            ETHTroveLogic: ETHTroveLogic.address
        }
    });

    const newImpl = await deployOrLoadAndVerify("ETHTroveLPImplV5", "ETHTroveStrategy", [], 0, {
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
    // await proxy.upgradeToAndCall(newImpl.address, initDecode);
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
