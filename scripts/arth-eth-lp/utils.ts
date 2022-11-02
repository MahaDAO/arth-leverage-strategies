import * as config from "./constants";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { BigNumber } from "ethers";

export const reportBalances = async (hre: HardhatRuntimeEnvironment, who: string) => {
    const weth = await hre.ethers.getContractAt("IERC20", config.wethAddr);
    const arth = await hre.ethers.getContractAt("IERC20", config.arthAddr);

    const e16 = BigNumber.from(10).pow(16);

    console.log("\n");
    console.log(" ---- balances of:", who);
    console.log(" -- arth       :", (await arth.balanceOf(who)).div(e16).toNumber() / 100);
    console.log(" -- weth       :", (await weth.balanceOf(who)).div(e16).toNumber() / 100);
    console.log(
        " -- eth        :",
        (await hre.ethers.provider.getBalance(who)).div(e16).toNumber() / 100
    );
    console.log("\n");
};

const MIN_TICK = -887272;
const MAX_TICK = -MIN_TICK;
export function nearestUsableTick(tick: number, tickSpacing: number) {
    const rounded = Math.round(tick / tickSpacing) * tickSpacing;
    if (rounded < MIN_TICK) return rounded + tickSpacing;
    else if (rounded > MAX_TICK) return rounded - tickSpacing;
    else return rounded;
}
