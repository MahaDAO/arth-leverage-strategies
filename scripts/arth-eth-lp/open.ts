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

    /**
     * A helper fn to calculate all the params to feed into the contract; things like debt, tick values etc..
     *
     * @param principalETH how much ETH is being added to the protocol
     * @param maxIL the max IL the user would like to take on. default is 10%
     */
    const getParams = async (principalETH: BigNumber, maxIL: number = 0.1) => {
        const slippage = 0.01; // 1% slippage
        const slot0 = await arthEthTroveLp.getSlot0();
        const tickSpacing = await arthEthTroveLp.getTickSpacing();
        const arthEthPrice = await arthEthTroveLp.lastGoodPrice();

        // understand how much ETH we will put into liquidty and how much we will
        // use to mint ARTH with. Ideally if we are expecting to put 10% of ARTH into
        // liquidty, then we use 90% into a trove to mint ARTH
        const troveETH = principalETH.mul(10000 * (1 - maxIL)).div(10000);
        const uniswapETH = principalETH.mul(10000 * maxIL).div(10000);

        // TODO: need to calculate maxFee and upper & lower hints

        // mint ARTH at a 250% CR
        // arth + fee = coll / (cr * price
        const gasFee = e18.mul(50);
        const cr = 250; // 250%
        const arthToMint = troveETH.mul(100).div(cr).mul(arthEthPrice).div(e18).sub(gasFee);

        const troveParams = {
            maxFee: e18, // uint256 maxFee;
            upperHint: "0x0000000000000000000000000000000000000000", // address upperHint;
            lowerHint: "0x0000000000000000000000000000000000000000", // address lowerHint;
            arthAmount: arthToMint, // uint256
            ethAmount: troveETH
        };

        console.log(
            `\tgetParams() > opening a loan at 250% cr with ${
                troveETH.mul(100).div(e18).toNumber() / 100
            }` + ` eth for ${arthToMint.mul(100).div(e18).toNumber() / 100} arth`
        );

        console.log(
            `\tgetParams() > adding liquidity with ${
                uniswapETH.mul(100).div(e18).toNumber() / 100
            } eth and ${arthToMint.mul(100).div(e18).toNumber() / 100} arth (~${
                arthToMint.mul(e18).div(arthEthPrice).mul(100).div(e18).toNumber() / 100
            } eth)`
        );

        // now that we know how much ETH and ARTH we need to add to liquidity; we decide what are the tick
        // values we will provide to Uniswap

        const currentSqrtPriceX96 = slot0[0];
        const currentTick = slot0[1];
        console.log("slot0", slot0);

        // if we say 20% above current price and 80% below current price
        const tickLower = nearestUsableTick(currentTick, tickSpacing) + tickSpacing * 2;
        const tickUpper = nearestUsableTick(currentTick, tickSpacing) + tickSpacing * 2;

        console.log("SqrtPriceX96", currentSqrtPriceX96.toString());
        console.log("tick", currentTick, tickLower, tickUpper, tickSpacing);

        const uniswapPoisitionMintParams = {
            arthAmountDesired: arthToMint, // amount0Desired: string;
            ethAmountMin: uniswapETH.mul((1 - slippage) * 10000).div(10000), // amount0Min: string;
            ethAmountDesired: uniswapETH, // amount1Desired: string;
            arthAmountMin: arthToMint.mul((1 - slippage) * 10000).div(10000), // amount1Min: string;
            tickLower: tickLower, // "-76000", // tickLower: string;
            tickUpper: tickUpper // "-60000" // tickUpper: string;
        };

        return {
            eth: principalETH,
            troveParams,
            uniswapPoisitionMintParams
        };
    };

    const params = await getParams(e18.mul(3));

    console.log("deposit", params.troveParams, params.uniswapPoisitionMintParams);
    await arthEthTroveLp
        .connect(deployer)
        .deposit(params.troveParams, params.uniswapPoisitionMintParams, {
            value: params.eth
        });

    console.log("flushing contract");
    await arthEthTroveLp.connect(deployer).flush(deployer.address, false, 0);

    console.log(await arthEthTroveLp.positions(deployer.address));

    await reportBalances(hre, arthEthTroveLp.address);
    await reportBalances(hre, deployer.address);
});
