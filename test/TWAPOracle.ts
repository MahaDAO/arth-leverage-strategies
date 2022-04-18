import { expect } from "chai";
import { BigNumber, Contract } from "ethers";
import { ethers } from "hardhat";

describe("TWAPOracle", async function () {
  const { provider } = ethers;

  const one = BigNumber.from(10).pow(18);
  const precision = BigNumber.from(10).pow(9);

  let dummyOracle: Contract;
  let twapOracle: Contract;

  // before("setup accounts & deploy libraries", async () => {
  //   [deployer, whale, me] = await ethers.getSigners();
  // });

  beforeEach(async function () {
    const MockOracle = await ethers.getContractFactory("MockOracle");
    const TWAPOracle = await ethers.getContractFactory("TWAPOracle");

    dummyOracle = await MockOracle.deploy(one);
    twapOracle = await TWAPOracle.deploy(dummyOracle.address, 86400, precision.mul(5));
  });

  it("Should deploy properly", async function () {
    expect(await twapOracle.oracle()).to.be.equal(dummyOracle.address);
    expect(await twapOracle.period()).to.be.equal(86400);
  });

  describe("pass one epoch with no price change", async function () {
    beforeEach(async function () {
      await provider.send("evm_increaseTime", [3600]);
      await twapOracle.updatePrice();
    });

    it("Should report price properly", async function () {
      expect(await twapOracle.fetchPrice()).to.be.equal(one);
    });
  });

  describe("fail one epoch with a large price change", async function () {
    beforeEach(async function () {
      await provider.send("evm_increaseTime", [3600]);
      await dummyOracle.setPrice(one.mul(1000));
    });

    it("Should revert", async function () {
      await expect(twapOracle.updatePrice()).to.be.revertedWith("too much price deviation");
    });
  });

  describe("pass one epoch with a small price change", async function () {
    beforeEach(async function () {
      await provider.send("evm_increaseTime", [3600]);
      await dummyOracle.setPrice(one.mul(101).div(100));
      await twapOracle.updatePrice();
    });

    it("Should report price properly", async function () {
      expect(await twapOracle.fetchPrice()).to.be.equal("1003333333333333333");
    });
  });
});
