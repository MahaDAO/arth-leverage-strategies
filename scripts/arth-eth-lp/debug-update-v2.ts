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

    const [deployer, whale] = await ethers.getSigners();
    console.log(`Deployer address is ${deployer.address}.`);
    console.log(`Whale address is ${whale.address}.`);
    // await reportBalances(hre, deployer.address);

    // const proxy = await ethers.getContractAt(
    //     "TransparentUpgradeableProxy",
    //     "0xA9735E594624339f8fbc8a99c57C13C7B4E8BCaC"
    // );
    // const proxy = await deployOrLoadAndVerify(
    //     "TransparentUpgradeableProxy2",
    //     "TransparentUpgradeableProxy",
    //     []
    // );

    // // DEBUG! manually override the proxy admin
    // console.log("manually override the proxy admin");
    // const abi = ethers.utils.defaultAbiCoder;
    // const params = abi.encode(["address"], [deployer.address]);
    // await ethers.provider.send("hardhat_setStorageAt", [
    //     proxy.address,
    //     "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103",
    //     params
    // ]);
    // console.log("proxy admin", await proxy.callStatic.proxyAdmin());

    console.log("Deploying ETHTroveLogic...");
    const ETHTroveLogic = await deployOrLoadAndVerify("ETHTroveLogic", "ETHTroveLogic", []);

    console.log("Deploying ETHTroveStrategy...");
    const factory = await ethers.getContractFactory("ETHTroveStrategy", {
        libraries: {
            ETHTroveLogic: ETHTroveLogic.address
        }
    });

    const newImpl = await deployOrLoad("ETHTroveLPImplV2", "ETHTroveStrategy", [], {
        libraries: {
            ETHTroveLogic: ETHTroveLogic.address
        }
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

    const proxy = await deployOrLoadAndVerify("ARTHETHTroveLP", "TransparentUpgradeableProxy", [
        newImpl.address,
        config.gnosisProxy,
        initDecode
    ]);

    const instance = await ethers.getContractAt("ETHTroveStrategy", proxy.address);

    console.log("upgraded!");
    console.log("impl address", await proxy.callStatic.implementation());

    // todo: should report all previous values properly; especially positions
    console.log("position[deployer]", await instance.connect(whale).positions(deployer.address));
    console.log("totalmArthSupplied", await instance.connect(whale).totalmArthSupplied());
    console.log("treasury", await instance.connect(whale).treasury());
    console.log("revenueMArth", await instance.connect(whale).revenueMArth());
    console.log("canInitialize", await instance.connect(whale).canInitialize());
    console.log("getRevision", await instance.connect(whale).getRevision());
    console.log("rewardRate", await instance.connect(whale).rewardRate());
    console.log("rewardsDuration", await instance.connect(whale).rewardsDuration());
    console.log("lastUpdateTime", await instance.connect(whale).lastUpdateTime());
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
