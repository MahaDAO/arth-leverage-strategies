/* eslint-disable */

import { BigNumber } from "ethers";
import hre, { ethers, network } from "hardhat";
import { deployOrLoadAndVerify } from "../utils";
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

    console.log("Deploying ARTHETHTroveLP...");
    const ARTHETHTroveLP = await ethers.getContractFactory("ARTHETHTroveLP");
    const implementation = await deployOrLoadAndVerify("ARTHETHTroveLPImpl", "ARTHETHTroveLP", []);

    // deploy as proxy
    console.log("Deploying proxy...");
    const initDecode = ARTHETHTroveLP.interface.encodeFunctionData("initialize", [
        config.borrowerOperationsAddr,
        config.arthAddr,
        config.mahaAddr,
        config.priceFeed,
        config.lendingPool,
        deployer.address
    ]);

    const proxy = await deployOrLoadAndVerify("ARTHETHTroveLP", "TransparentUpgradeableProxy", [
        implementation.address,
        config.gnosisSafe,
        initDecode
    ]);
    const arthEthTroveInstance = await ethers.getContractAt("ARTHETHTroveLP", proxy.address);
    console.log("ARTHETHTRoveLp deployed at", arthEthTroveInstance.address);

    await reportBalances(hre, arthEthTroveInstance.address);

    // console.log("Opening trove...");
    // console.log("funding contract and opening trove");
    // await arthEthTroveInstance
    //     .connect(deployer)
    //     .openTrove(
    //         e18,
    //         e18.mul(251),
    //         config.ZERO_ADDRESS,
    //         config.ZERO_ADDRESS,
    //         config.ZERO_ADDRESS,
    //         {
    //             value: e18.mul(2)
    //         }
    //     );

    // await reportBalances(hre, arthEthTroveInstance.address);
    await reportBalances(hre, deployer.address);
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
