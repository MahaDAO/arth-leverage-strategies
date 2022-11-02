import { task } from "hardhat/config";

task("arth-eth:test", "Test ARTH/ETH Loan").setAction(async (pramas, hre) => {
    await hre.run("arth-eth:open");
    await hre.run("arth-eth:close");
});
