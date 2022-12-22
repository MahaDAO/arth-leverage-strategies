/* eslint-disable */

import { BigNumber } from "ethers";
import hre, { ethers, network } from "hardhat";
import { deployOrLoadAndVerify, getOutputAddress } from "../utils";
// eslint-disable-next-line node/no-missing-import
import * as config from "./constants";
// eslint-disable-next-line node/no-missing-import
import { reportBalances } from "./utils";

async function main() {
    console.log(`Deploying to ${network.name}...`);

    const e18 = BigNumber.from(10).pow(18);

    const deployer = await ethers.getSigner(config.deployer);
    console.log(`Deployer address is ${deployer.address}.`);
    await reportBalances(hre, deployer.address);

    const proxy = await ethers.getContractAt(
        "TransparentUpgradeableProxy",
        getOutputAddress("ARTHETHTroveLP", "ethereum")
    );
    const instance = await ethers.getContractAt("ARTHETHTroveLP", proxy.address);

    console.log("Deploying ARTHETHTroveLP...");
    const factory = await ethers.getContractFactory("ETHTroveStrategy");
    const implementation = await deployOrLoadAndVerify("ETHTroveLPImplV2", "ETHTroveStrategy", []);

    // deploy as proxy
    console.log("Deploying proxy...");
    const initDecode = factory.interface.encodeFunctionData("initialize", [
        config.borrowerOperationsAddr, // address _borrowerOperations,
        config.arthAddr, // address __arth,
        config.mahaAddr, // address __maha,
        config.priceFeed, // address _priceFeed,
        config.lendingPool, // address _pool,
        86400 * 30, // uint256 _rewardsDuration,
        deployer.address, // address _owner,
        config.gnosisSafe, // address _treasury,
        e18.mul(250).div(100) // uint256 _minCr 250%
    ]);

    console.log("new implementation", implementation.address);
    console.log("init code", initDecode);

    await proxy.upgradeToAndCall(implementation.address, initDecode);

    // todo: should report all previous values properly; especially positions
    console.log("position[deployer]", await instance.positions(deployer.address));
    console.log("totalmArthSupplied", await instance.totalmArthSupplied());
    console.log("treasury", await instance.treasury());
    console.log("revenueMArth", await instance.revenueMArth());
    console.log("canInitialize", await instance.canInitialize());
    console.log("getRevision", await instance.getRevision());
    console.log("rewardRate", await instance.rewardRate());
    console.log("lastUpdateTime", await instance.lastUpdateTime());
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
