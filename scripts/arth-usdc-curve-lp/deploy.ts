/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { deployOrLoadAndVerify } from "../utils";
import * as config from "./constants";

async function main() {
    const deployer = (await ethers.getSigners())[0];

    console.log("Deploying ETHTroveLogic...");
    const USDCCurveLogic = await deployOrLoadAndVerify("USDCCurveLogic", "USDCCurveLogic", []);

    const libraries = { USDCCurveLogic: USDCCurveLogic.address };

    const implementation = await deployOrLoadAndVerify(
        "USDCCurveStrategyInstance",
        "USDCCurveStrategy",
        [],
        4000,
        libraries
    );

    const USDCCurveLP = await ethers.getContractFactory("USDCCurveStrategy", { libraries });
    const initDecode = USDCCurveLP.interface.encodeFunctionData("initialize", [
        config.usdcAddr, // address _usdc,
        config.arthAddr, // address _arth,
        config.mahaAddr, // address _maha,
        config.curveLp,
        config.varDebtArth,
        config.lendingPoolAddr, // address _lendingPool,
        config.stableSwapAddr, // address _liquidityPool,
        86400 * 30, // uint256 _rewardsDuration,
        config.priceFeedAddr, // address _priceFeed,
        config.treasury, // address _treasury,
        deployer.address // address _owner
    ]);

    const proxy = await deployOrLoadAndVerify("USDCCurveStrategy", "TransparentUpgradeableProxy", [
        implementation.address,
        config.gnosisProxy,
        initDecode
    ]);

    console.log("USDCCurveStrategy deployed at", proxy.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
