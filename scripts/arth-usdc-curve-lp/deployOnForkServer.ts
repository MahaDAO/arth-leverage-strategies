/* eslint-disable */
import hre, { ethers } from "hardhat";
import { wait } from "../utils";
import { BigNumber } from "ethers";

async function main() {
    const deployer = (await ethers.getSigners())[0];

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: ["0x658b0f629B9e3753AA555C189D0cB19C1eD59632"],
    });
    hre.network.provider.request({
        method: "hardhat_setBalance",
        params: ["0x658b0f629B9e3753AA555C189D0cB19C1eD59632", BigNumber.from(10).pow(18).mul(1000).toHexString()]
    });

    const signer = await ethers.getSigner("0x658b0f629B9e3753AA555C189D0cB19C1eD59632")

    const ARTHUSDCCurveLP = await ethers.getContractFactory("ARTHUSDCCurveLP");
    console.log("Deployer is ", deployer.address);
    console.log("Deploying contract");
    const instance = await ARTHUSDCCurveLP.deploy();
    console.log("Tx submitted");
    await instance.deployed();
    console.log("ARTHUSDCCurveLP deployed to:", instance.address);

    console.log("Initializing...");
    (await instance.initialize(
        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", // usdc
        "0x8cc0f052fff7ead7f2edcccac895502e884a8a71", // arth
        "0xb4d930279552397bba2ee473229f89ec245bc365", // maha
        "0x76F0C94Ced5B48020bf0D7f3D0CEabC877744cB5", // lending pool
        "0xb4018cb02e264c3fcfe0f21a1f5cfbcaaba9f61f", // liquidity pool
        "2592000",
        deployer.address,
        deployer.address
    )).wait();

    console.log("Opening position", signer.address);

    const usdc = await ethers.getContractAt("IERC20", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
    const arth = await ethers.getContractAt("IERC20", "0x8cc0f052fff7ead7f2edcccac895502e884a8a71");

    await (await usdc.connect(signer).approve(instance.address, BigNumber.from(10).pow(30))).wait();
    await (await arth.connect(signer).approve(instance.address, BigNumber.from(10).pow(30))).wait();
    console.log("USDC balance", (await usdc.balanceOf(signer.address)).toString(), BigNumber.from(10).pow(18).mul(75).div(100).toString());

    const params =
    {
        arthToBorrow: BigNumber.from(10).pow(18).mul(104).div(100),
        totalUsdcSupplied: BigNumber.from(10).pow(6).mul(5),
        minUsdcInLp: 0,
        minArthInLp: 0,
        minLiquidityReceived: 0,
        lendingReferralCode: 0,
        interestRateMode: 1
    }

    await instance.connect(signer).deposit(params);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
