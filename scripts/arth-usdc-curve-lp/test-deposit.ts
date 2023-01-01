import hre, { ethers } from "hardhat";
import { BigNumber } from "ethers";
// eslint-disable-next-line node/no-missing-import
import * as config from "./constants";
import { deployOrLoadAndVerify } from "../utils";

async function main() {
    const deployer = (await ethers.getSigners())[0];

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: ["0xf977814e90da44bfa03b6295a0616a897441acec"] // impersonate binance wallet for now; has 1bn USDC
    });

    const e18 = BigNumber.from(10).pow(18);
    const e6 = BigNumber.from(10).pow(6);

    const whale = await ethers.getSigner("0xf977814e90da44bfa03b6295a0616a897441acec");

    console.log("Deploying ETHTroveLogic...");
    const ARTHUSDCCurveLogic = await deployOrLoadAndVerify(
        "ARTHUSDCCurveLogic",
        "ARTHUSDCCurveLogic",
        []
    );

    const ARTHUSDCCurveLP = await ethers.getContractFactory("ARTHUSDCCurveLP", {
        libraries: { ARTHUSDCCurveLogic: ARTHUSDCCurveLogic.address }
    });

    console.log("Deploying contract");
    const instance = await ARTHUSDCCurveLP.deploy();
    console.log("Tx submitted");
    await instance.deployed();
    console.log("ARTHUSDCCurveLP deployed to:", instance.address);

    console.log("Initializing...");
    (
        await instance.initialize(
            config.usdcAddr, // address _usdc,
            config.arthAddr, // address _arth,
            config.mahaAddr, // address _maha,
            config.lendingPoolAddr, // address _lendingPool,
            config.stableSwapAddr, // address _liquidityPool,
            86400 * 30, // uint256 _rewardsDuration,
            deployer.address, // address _operator,
            deployer.address, // address _treasury,
            deployer.address // address _owner
        )
    ).wait();

    console.log("Opening position", whale.address);

    const usdc = await ethers.getContractAt("IERC20", config.usdcAddr);

    await (await usdc.connect(whale).approve(instance.address, BigNumber.from(10).pow(30))).wait();

    console.log(
        "USDC balance",
        (await usdc.balanceOf(whale.address)).toString(),
        BigNumber.from(10).pow(18).mul(75).div(100).toString()
    );

    const params = {
        arthToBorrow: e18.mul(100),
        totalUsdcSupplied: e6.mul(500),
        minUsdcInLp: 0,
        minArthInLp: 0,
        minLiquidityReceived: 0,
        // lendingReferralCode: 0,
        interestRateMode: 1
    };

    await instance.connect(whale).deposit(params);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
