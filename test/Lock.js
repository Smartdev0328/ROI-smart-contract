const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { ethers } = require("hardhat");

describe("Lock", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  it("Deployment", async function () {
    //const [owner] = await ethers.getSigner();
    const roi = await ethers.getContractFactory("DivineRoi");
    const roiContract = await roi.deploy();
    const price = await roiContract.deposit({value:ethers.utils.parseEther("15")});
    console.log("asdf:", price)
  });


});
