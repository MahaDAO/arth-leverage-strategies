/* eslint-disable node/no-missing-import */
import { ethers } from "hardhat";
import { deployOrLoadAndVerify } from "../utils";

async function main() {
    const deployer = (await ethers.getSigners())[0];

    console.log("Deploying ETHTroveLogic...");
    const usdc = await deployOrLoadAndVerify("USDC", "MockERC20Permit", ["USDC", "USDC", 6]);
    const maha = await deployOrLoadAndVerify("MAHA", "MockERC20Permit", ["MAHA", "MAHA", 18]);

    await deployOrLoadAndVerify("USDCCurveStrategyTestnet", "USDCCurveStrategyTestnet", [
        usdc.address, // address _usdc,
        maha.address, // address _maha,
        86400 * 30, // uint256 _rewardsDuration,
        deployer.address // address _owner
    ]);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
