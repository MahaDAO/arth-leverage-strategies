import { BigNumber } from "ethers";
import { task } from "hardhat/config";
// eslint-disable-next-line node/no-missing-import
import * as config from "./constants";
// eslint-disable-next-line node/no-missing-import
import { reportBalances } from "./utils";

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

    console.log("Deploying ARTHETHTroveLP...");
    const ARTHETHTroveLP = await hre.ethers.getContractFactory("ARTHETHTroveLP");
    const arthEthTroveLp = await ARTHETHTroveLP.connect(deployer).deploy(
        config.borrowerOperationsAddr,
        config.arthAddr,
        config.mahaAddr,
        config.priceFeed,
        config.lendingPool
    );
    console.log("ARTHETHTRoveLp deployed at", arthEthTroveLp.address);

    await reportBalances(hre, arthEthTroveLp.address);

    console.log("Opening trove...");
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

    console.log("depositing 2 eth, opening a loan and adding to LP");

    const loanParams = {
        maxFee: e18,
        upperHint: config.ZERO_ADDRESS,
        lowerHint: config.ZERO_ADDRESS,
        arthAmount: e18.mul(251)
    };

    await arthEthTroveLp.connect(deployer).deposit(loanParams, 0, {
        value: e18.mul(2)
    });

    console.log("flushing contract");

    console.log(await arthEthTroveLp.positions(deployer.address));

    await reportBalances(hre, arthEthTroveLp.address);
    await reportBalances(hre, deployer.address);
});
