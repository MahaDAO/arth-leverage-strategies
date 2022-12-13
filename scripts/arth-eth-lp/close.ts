import { BigNumber } from "ethers";
import { task } from "hardhat/config";
// eslint-disable-next-line node/no-missing-import
import * as config from "./constants";
// eslint-disable-next-line node/no-missing-import
import { reportBalances } from "./utils";

task("arth-eth:close", "Close ARTH/ETH Loan").setAction(async (pramas, hre) => {
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
    await reportBalances(hre, deployer.address, "deployer");

    console.log("Deploying ARTHETHTroveLP...");
    const ARTHETHTroveLP = await hre.ethers.getContractFactory("ARTHETHTroveLP");
    const arthEthTroveImpl = await ARTHETHTroveLP.connect(deployer).deploy();

    // deploy as proxy
    console.log("Deploying proxy...");
    const ProxyFactory = await hre.ethers.getContractFactory("TransparentUpgradeableProxy");
    const initDecode = ARTHETHTroveLP.interface.encodeFunctionData("initialize", [
        config.borrowerOperationsAddr,
        config.arthAddr,
        config.mahaAddr,
        config.priceFeed,
        config.lendingPool,
        deployer.address
    ]);
    const proxy = await ProxyFactory.deploy(arthEthTroveImpl.address, config.gnosisSafe, initDecode);
    const arthEthTroveLp = await hre.ethers.getContractAt("ARTHETHTroveLP", proxy.address);
    console.log("ARTHETHTRoveLp deployed at", arthEthTroveLp.address);

    await reportBalances(hre, arthEthTroveLp.address, "contract");

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

    await reportBalances(hre, arthEthTroveLp.address, "contract");
    await reportBalances(hre, deployer.address, "deployer");

    console.log("depositing 1 eth, opening a loan and adding to mahalend");
    await arthEthTroveLp.connect(deployer).deposit(
        {
            maxFee: e18,
            upperHint: config.ZERO_ADDRESS,
            lowerHint: config.ZERO_ADDRESS,
            arthAmount: e18.mul(251)
        },
        0,
        {
            value: e18.mul(2)
        }
    );
    await reportBalances(hre, arthEthTroveLp.address, "contract");
    await reportBalances(hre, deployer.address, "deployer");

    console.log("withdrawing position");
    await arthEthTroveLp.connect(deployer).withdraw({
        maxFee: e18,
        upperHint: config.ZERO_ADDRESS,
        lowerHint: config.ZERO_ADDRESS,
        arthAmount: e18.mul(251)
    });
    await reportBalances(hre, arthEthTroveLp.address, "contract");
    await reportBalances(hre, deployer.address, "deployer");

    console.log("closing contract");
    await arthEthTroveLp.connect(deployer).closeTrove(e18.mul(251));
    await reportBalances(hre, arthEthTroveLp.address, "contract");
    await reportBalances(hre, deployer.address, "deployer");
});
