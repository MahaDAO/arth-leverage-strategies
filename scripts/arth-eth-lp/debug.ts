/* eslint-disable */

import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";
import { wait } from "../utils";

async function main() {
    console.log(`Debugging to ${network.name}...`);

    const [deployer] = await ethers.getSigners();
    const e18 = BigNumber.from(10).pow(18);

    const address = "0x6b41d394e2DfF2DE63f62959A79Dac372379Dd54";
    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [address]
    });
    const impersonatedSigner = await ethers.getSigner(address);

    console.log(`Deployer address is ${deployer.address}.`);

    const fee = "10000";
    const mahaAddr = "0xb4d930279552397bba2ee473229f89ec245bc365";
    const arthAddr = "0x8CC0F052fff7eaD7f2EdCCcaC895502E884a8a71";
    const wethAddr = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
    const uniswapV3PoolAddr = "0xfD6c2A0674796D0452534846f4c90923352C716b";
    const borrowerOperationsAddr = "0xD3761E54826837B8bBd6eF0A278D5b647B807583";
    const uniswapV3SwapRouterAddr = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
    const uniswapNFTPositionMangerAddr = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88";
    const troveManager = "0xF4eD5d0C3C977B57382fabBEa441A63FAaF843d3";
    const priceFeed = "0x15726a29c398e65Ae5dA551DFf3BBC26D767d0F7";

    const arth = await ethers.getContractAt("IERC20", arthAddr);
    const weth = await ethers.getContractAt("IERC20", wethAddr);

    const ARTHETHTroveLP = await ethers.getContractFactory("ARTHETHTroveLP");
    console.log("Deploying...");
    const arthEthTroveLp = await ARTHETHTroveLP.connect(impersonatedSigner).deploy(
        borrowerOperationsAddr,
        uniswapNFTPositionMangerAddr,
        arthAddr,
        mahaAddr,
        wethAddr,
        fee,
        uniswapV3SwapRouterAddr,
        priceFeed,
        false
    );
    console.log("ARTHETHTRoveLp deployed at", arthEthTroveLp.address);
    console.log("Opening trove...");

    const troveParams = {
        maxFee: e18, // uint256 maxFee;
        upperHint: "0x0000000000000000000000000000000000000000", // address upperHint;
        lowerHint: "0x0000000000000000000000000000000000000000", // address lowerHint;
        arthAmount: e18.mul(251), // uint256
        ethAmount: e18.mul(15).div(10) // uint256
    };

    const uniswapPoisitionMintParams = {
        ethAmountDesired: e18.mul(251), // amount0Desired: string;
        ethAmountMin: "0", // amount0Min: string;
        arthAmountDesired: e18.mul(15).div(10), // amount1Desired: string;
        arthAmountMin: "0", // amount1Min: string;
        tickLower: "-76000", // tickLower: string;
        tickUpper: "-60000" // tickUpper: string;
    };

    // int24 tickLower;
    // int24 tickUpper;
    // uint256 ethAmountMin;
    // uint256 ethAmountDesired;
    // uint256 arthAmountMin;
    // uint256 arthAmountDesired;

    const whitelistParams = {
        rootId: "",
        proof: []
    };

    await arthEthTroveLp
        .connect(impersonatedSigner)
        .openTrove(e18, e18.mul(251), ZERO_ADDRESS, ZERO_ADDRESS, ZERO_ADDRESS, {
            value: e18.mul(2)
        });

    await arthEthTroveLp.connect(impersonatedSigner).flush(impersonatedSigner.address, false, 0);

    console.log("Depositing");
    const tx = await arthEthTroveLp
        .connect(impersonatedSigner)
        .deposit(troveParams, uniswapPoisitionMintParams, whitelistParams, {
            value: "3000000000000000000"
        });
}

main().catch(error => {
    console.error(error);
    process.exitCode = 1;
});
