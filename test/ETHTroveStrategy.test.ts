import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { ETHTroveStrategy, IERC20, ILendingPool, ITroveManager } from "../typechain";
import { time } from "@nomicfoundation/hardhat-network-helpers";

const mahaAddr = "0xB4d930279552397bbA2ee473229f89Ec245bc365";
const arthAddr = "0x8CC0F052fff7eaD7f2EdCCcaC895502E884a8a71";
const zeroAddr = "0x0000000000000000000000000000000000000000";
const borrowerOperationsAddr = "0xD3761E54826837B8bBd6eF0A278D5b647B807583";
const priceFeedAddr = "0xCB056C17ce063F20a8D0650F30550B20Ff1f04c1";
const lendingPoolAddr = "0x76F0C94Ced5B48020bf0D7f3D0CEabC877744cB5";
const mArthAddr = "0xE6B683868D1C168Da88cfe5081E34d9D80E4D1a6";
const troveManagerAddr = "0xf4ed5d0c3c977b57382fabbea441a63faaf843d3";
const treasuryAddr = "0x9032F1Bd0cc645Fde1b41941990dA85f265A7623";

describe("ETHTroveStrategy", async () => {
    let strategy: ETHTroveStrategy;
    let lendingPool: ILendingPool;
    let troveManager: ITroveManager;

    let arth: IERC20;
    let mArth: IERC20;
    let maha: IERC20;

    let deployer: SignerWithAddress;
    let whale: SignerWithAddress;
    let ant: SignerWithAddress;

    const e18 = BigNumber.from(10).pow(18);
    const mcr = e18.mul(25).div(10);

    beforeEach(async function () {
        const libraryFactory = await ethers.getContractFactory("ETHTroveLogic");
        const ETHTroveLogic = await libraryFactory.deploy();

        const strategyFactory = await ethers.getContractFactory("ETHTroveStrategy", {
            libraries: {
                ETHTroveLogic: ETHTroveLogic.address
            }
        });
        [deployer, whale, ant] = await ethers.getSigners();

        lendingPool = await ethers.getContractAt("ILendingPool", lendingPoolAddr);
        maha = await ethers.getContractAt("ERC20", mahaAddr);
        arth = await ethers.getContractAt("ERC20", arthAddr);
        mArth = await ethers.getContractAt("ERC20", mArthAddr);

        troveManager = await ethers.getContractAt("ITroveManager", troveManagerAddr);

        // deploy and init strategy
        strategy = await strategyFactory.deploy();
        await strategy.initialize(
            borrowerOperationsAddr,
            arthAddr,
            mahaAddr,
            priceFeedAddr,
            lendingPool.address,
            86400 * 30, // 30 day rewards
            deployer.address,
            treasuryAddr,
            mcr
        );
    });

    it("should deploy addresses properly", async function () {
        expect(await strategy.owner()).eq(deployer.address);
        expect(await strategy.operator()).eq(deployer.address);
        expect(await strategy.mArth()).eq(mArthAddr);
        expect(await strategy.pool()).eq(lendingPoolAddr);

        expect(await strategy.operator()).eq(deployer.address);
        expect(await strategy.rewardsToken()).eq(maha.address);

        expect(await strategy.rewardsDuration()).eq(86400 * 30);
        expect(await strategy.totalmArthSupplied()).eq(0);
        expect(await strategy.minCollateralRatio()).eq(mcr);
    });

    describe("open trove via admin", async () => {
        beforeEach(async () => {
            // open the trove via admin
            await strategy.openTrove(e18, e18.mul(1000), zeroAddr, zeroAddr, { value: e18.mul(10) });
        });

        // it("should record");

        describe("valid deposit(...) - 10 eth", async () => {
            const depositLoanParams = {
                maxFee: e18, // maxFee: BigNumberish;
                upperHint: zeroAddr, // upperHint: string;
                lowerHint: zeroAddr, // lowerHint: string;
                arthAmount: e18.mul(1000) // arthAmount: BigNumberish;
            };

            beforeEach(async () => {
                await strategy.connect(whale).deposit(depositLoanParams, { value: e18.mul(10) });
            });

            it("should record position properly", async () => {
                const position = await strategy.positions(whale.address);
                const positionCR = await strategy.callStatic.getPositionCR(whale.address);
                expect(position.isActive).eq(true);
                expect(positionCR).eq("5729384837886236308");
                expect(position.arthFromLoan).eq(depositLoanParams.arthAmount);
            });

            it("should record internal variables properly", async () => {
                expect(await strategy.totalmArthSupplied()).eq(depositLoanParams.arthAmount);
                expect(await strategy.totalSupply()).eq(e18.mul(10)); // staking values
            });

            it("should deposit liquidity into mahalend", async () => {
                expect(await mArth.balanceOf(strategy.address)).eq(depositLoanParams.arthAmount);
            });

            it("should open a trove on arth loans", async () => {
                const trove = await troveManager.Troves(strategy.address);
                console.log(trove);

                // 10 eth initial + 10 eth from whale
                expect(trove.coll, "has enough eth").eq(e18.mul(10 + 10));

                // 1000 arth inital + 50 arth liquidation fee + 1000 arth from whale
                expect(trove.debt, "has minted enough arth").eq(e18.mul(1000 + 1000 + 50));
            });

            describe("valid withdraw(...)", async () => {
                const withdrawLoanParams = {
                    maxFee: e18, // maxFee: BigNumberish;
                    upperHint: zeroAddr, // upperHint: string;
                    lowerHint: zeroAddr, // lowerHint: string;
                    arthAmount: e18.mul(1000) // arthAmount: BigNumberish;
                };

                it("should return 10 eth back to the user", async () => {
                    expect((await whale.getBalance()).div(e18)).eq(9989);
                    await strategy.connect(whale).withdraw(withdrawLoanParams);
                    expect((await whale.getBalance()).div(e18)).eq(9999);
                });

                it("should fail if the user has not deposited before", async () => {
                    await expect(
                        strategy.connect(ant).withdraw(withdrawLoanParams)
                    ).to.be.revertedWith("Cannot withdraw 0");
                });

                it("should generate revenue after 1 year of interest", async () => {
                    expect(await strategy.revenueMArth(), "0 revenue before").eq(0);

                    // advance time by one year and mine a new block
                    await time.increase(86400 * 365);

                    // withdraw
                    await strategy.connect(whale).withdraw(withdrawLoanParams);

                    // revenue should also be valid
                    expect(await strategy.revenueMArth(), "valid revenue").gt(0);
                    await strategy.collectRevenue();
                    expect(await strategy.revenueMArth(), "0 revenue after").eq(0);
                });

                it("should generate revenue after 1 year of interest and closing everything", async () => {
                    // advance time by one year and mine a new block
                    await time.increase(86400 * 365);

                    // withdraw
                    await strategy.connect(whale).withdraw(withdrawLoanParams);

                    // close everything
                    await strategy.closeTrove(await arth.balanceOf(strategy.address));

                    // collect revenue
                    expect(await strategy.revenueMArth(), "valid revenue").gt(0);
                    await strategy.collectRevenue();
                    expect(await strategy.revenueMArth(), "0 revenue after").eq(0);
                });
            });

            describe.only("invalid withdraw(...)", async () => {
                // TODO
            });
        });

        describe.skip("invalid deposit(...)", async () => {
            it("should not open position if no eth was given", async () => {
                const loanParams = {
                    maxFee: e18, // maxFee: BigNumberish;
                    upperHint: zeroAddr, // upperHint: string;
                    lowerHint: zeroAddr, // lowerHint: string;
                    arthAmount: e18.mul(1000) // arthAmount: BigNumberish;
                };

                await expect(
                    strategy.connect(whale).deposit(loanParams, { value: e18.mul(0) })
                ).to.be.revertedWith("no eth");
            });

            it("should not open position if loan CR was too low", async () => {
                const loanParams = {
                    maxFee: e18, // maxFee: BigNumberish;
                    upperHint: zeroAddr, // upperHint: string;
                    lowerHint: zeroAddr, // lowerHint: string;
                    arthAmount: e18.mul(100000) // arthAmount: BigNumberish;
                };

                await expect(
                    strategy.connect(whale).deposit(loanParams, { value: e18 })
                ).to.be.revertedWith("min CR not met");
            });

            it("should not open position if position was already open", async () => {
                const loanParams = {
                    maxFee: e18, // maxFee: BigNumberish;
                    upperHint: zeroAddr, // upperHint: string;
                    lowerHint: zeroAddr, // lowerHint: string;
                    arthAmount: e18 // arthAmount: BigNumberish;
                };

                // this should go through
                await strategy.connect(whale).deposit(loanParams, { value: e18 });

                // this should fail
                await expect(
                    strategy.connect(whale).deposit(loanParams, { value: e18 })
                ).to.be.revertedWith("position open");
            });
        });
    });
});
