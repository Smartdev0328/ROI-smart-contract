const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { ethers } = require("hardhat");
const {expect} = require("chai")

describe("Test", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  it("Deploy & Deposit", async function () {
   // const [owner] = await ethers.getSigner();
    const roi = await ethers.getContractFactory("DivineRoi");
    const roiContract = await roi.deploy();
    await roiContract.deposit({value:ethers.utils.parseEther("15")});
    
    //test deposit function
    expect(await ethers.provider.getBalance(roiContract.address)).to.equal(ethers.utils.parseEther("15"));
    
    const info = await roiContract.getDepositInfo(roi.signer.getAddress(), 0)
    expect(info.amount).to.equal(ethers.utils.parseEther("15"));

    await ethers.provider.send("evm_increaseTime", [3600*24*3]);
    await roiContract.deposit({value:ethers.utils.parseEther("15")});
    await ethers.provider.send("evm_increaseTime", [3600*24*3]);
    await roiContract.withdraw();
    //expect(await ethers.provider.getBalance(roiContract.address)).to.equal(ethers.utils.parseEther("30"));
  });


});
