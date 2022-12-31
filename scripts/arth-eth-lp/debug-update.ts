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

    const proxy = await ethers.getContractAt(
        "TransparentUpgradeableProxy",
        "0xA9735E594624339f8fbc8a99c57C13C7B4E8BCaC"
    );

    // DEBUG! manually override the proxy admin
    console.log("manually override the proxy admin");
    const abi = ethers.utils.defaultAbiCoder;
    const params = abi.encode(["address"], [deployer.address]);
    await ethers.provider.send("hardhat_setStorageAt", [
        proxy.address,
        "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103",
        params
    ]);

    console.log("proxy admin", await proxy.callStatic.proxyAdmin());

    const instance = await ethers.getContractAt("ETHTroveStrategy", proxy.address);

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

    console.log(">>> minCollateralRatio", await instance.connect(whale).minCollateralRatio());

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

    console.log(
        "position(e.eth)",
        await instance.connect(whale).positions("0xecce08c2636820a81fc0c805dbdc7d846636bbc4")
    );

    await proxy.upgradeToAndCall(newImpl.address, initDecode);

    console.log("upgraded!");

    console.log("impl address", await proxy.callStatic.implementation());

    // todo: should report all previous values properly; especially positions
    console.log(">>> minCollateralRatio", await instance.connect(whale).minCollateralRatio());
    console.log("totalmArthSupplied", await instance.connect(whale).totalmArthSupplied());
    console.log("treasury", await instance.connect(whale).treasury());
    console.log("canInitialize", await instance.connect(whale).canInitialize());
    console.log(
        "position(e.eth)",
        await instance.connect(whale).positions("0xecce08c2636820a81fc0c805dbdc7d846636bbc4")
    );
    console.log("getRevision", await instance.connect(whale).getRevision());
    console.log("rewardRate", await instance.connect(whale).rewardRate());
    console.log("rewardsDuration", await instance.connect(whale).rewardsDuration());
    console.log("lastUpdateTime", await instance.connect(whale).lastUpdateTime());

    console.log("revenueMArth", await instance.connect(whale).revenueMArth());
    await hre.network.provider.send("hardhat_mine", ["0x3472E"]); // 30 days - 214830 blocks
    console.log("revenueMArth", await instance.connect(whale).revenueMArth());

    // claim revenue!

    await instance.connect(whale).collectRevenue();
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
