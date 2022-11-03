import { BigNumber } from "ethers";
import { task } from "hardhat/config";
import * as config from "./constants";
import { nearestUsableTick, reportBalances } from "./utils";

task("arth-eth:open", "Open ARTH/ETH Loan").setAction(async (_taskArgs, hre) => {
    console.log(`Debugging to ${hre.network.name}...`);

    const e18 = BigNumber.from(10).pow(18);

    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [config.deployer]
    });
    hre.network.provider.request({
        method: "hardhat_setBalance",
        params: [config.deployer, e18.mul(1000).toHexString()]
    });

    const deployer = await hre.ethers.getSigner(config.deployer);
    console.log(`Deployer address is ${deployer.address}.`);
    await reportBalances(hre, deployer.address);

    console.log("Deploying ARTHETHRouter...");
    const ARTHETHRouter = await hre.ethers.getContractFactory("ARTHETHRouter");
    const arthETHRouter = await ARTHETHRouter.connect(deployer).deploy(
        config.arthAddr, // address __arth,
        config.wethAddr, // address __weth,
        config.fee, // uint24 _fee,
        config.uniswapV3SwapRouterAddr // address _uniswapV3SwapRouter
    );
    console.log("ARTHETHRouter deployed at", arthETHRouter.address);

    console.log("Deploying ARTHETHTroveLP...");
    const ARTHETHTroveLP = await hre.ethers.getContractFactory("ARTHETHTroveLP");
    const arthEthTroveLp = await ARTHETHTroveLP.connect(deployer).deploy(
        config.borrowerOperationsAddr,
        config.uniswapNFTPositionMangerAddr,
        config.arthAddr,
        config.mahaAddr,
        config.wethAddr,
        config.fee,
        arthETHRouter.address,
        config.priceFeed,
        config.uniswapV3PoolAddr
    );
    console.log("ARTHETHTRoveLp deployed at", arthEthTroveLp.address);
    await reportBalances(hre, arthEthTroveLp.address);

    console.log("Opening trove...");

    // const whitelistParams = {
    //     rootId: null,
    //     proof: []
    // };

    console.log("funding contract and opening trove");
    await arthEthTroveLp
        .connect(deployer)
        .openTrove(
            e18,
            e18.mul(251),
            config.ZERO_ADDRESS,
            config.ZERO_ADDRESS,
            config.ZERO_ADDRESS,
            {
                value: e18.mul(2)
            }
        );

    await reportBalances(hre, arthEthTroveLp.address);
    await reportBalances(hre, deployer.address);

    console.log("flushing contract");
    await arthEthTroveLp.connect(deployer).flush(deployer.address, false, 0);

    console.log("depositing 3 eth, opening a loan and adding to LP");

    const troveParams = {
        maxFee: e18, // uint256 maxFee;
        upperHint: "0x0000000000000000000000000000000000000000", // address upperHint;
        lowerHint: "0x0000000000000000000000000000000000000000", // address lowerHint;
        arthAmount: e18.mul(251), // uint256
        ethAmount: e18.mul(15).div(10) // uint256
    };

    const slot0 = await arthEthTroveLp.getSlot0();
    const tickSpacing = await arthEthTroveLp.getTickSpacing();

    const currentSqrtPriceX96 = slot0[0];
    const currentTick = slot0[1];
    console.log("slot0", slot0);

    // if we say 20% above current price and 80% below current price
    const tickLower = nearestUsableTick(currentTick, tickSpacing) + tickSpacing * 2;
    const tickUpper = nearestUsableTick(currentTick, tickSpacing) + tickSpacing * 2;

    console.log("SqrtPriceX96", currentSqrtPriceX96.toString());
    console.log("tick", currentTick, tickLower, tickUpper, tickSpacing);

    const uniswapPoisitionMintParams = {
        arthAmountDesired: e18.mul(251), // amount0Desired: string;
        ethAmountMin: "0", // amount0Min: string;
        ethAmountDesired: e18.mul(15).div(10), // amount1Desired: string;
        arthAmountMin: "0", // amount1Min: string;
        tickLower: tickLower, // "-76000", // tickLower: string;
        tickUpper: tickUpper // "-60000" // tickUpper: string;
    };

    console.log("deposit", troveParams, uniswapPoisitionMintParams);
    await arthEthTroveLp.connect(deployer).deposit(troveParams, uniswapPoisitionMintParams, {
        value: e18.mul(3)
    });

    console.log("flushing contract");
    await arthEthTroveLp.connect(deployer).flush(deployer.address, false, 0);

    console.log(await arthEthTroveLp.positions(deployer.address));

    await reportBalances(hre, arthEthTroveLp.address);
    await reportBalances(hre, deployer.address);
});
