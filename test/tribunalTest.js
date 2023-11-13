const { expect } = require("chai");

describe("CombinedTribunalNFT Contract", function () {
  let CombinedTribunalNFT;
  let combinedTribunalNFT;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    
    // Deploy the CombinedTribunalNFT contract
    CombinedTribunalNFT = await ethers.getContractFactory("CombinedTribunalNFT");
    combinedTribunalNFT = await CombinedTribunalNFT.deploy();
    await combinedTribunalNFT.deployed();
  });

  it("Should add and remove a valid address", async function () {
    // Add a valid address
    await combinedTribunalNFT.addValidAddress(user1.address);
    expect(await combinedTribunalNFT.validAddresses(user1.address)).to.equal(true);

    // Remove a valid address
    await combinedTribunalNFT.removeValidAddress(user1.address);
    expect(await combinedTribunalNFT.validAddresses(user1.address)).to.equal(false);
  });

  it("Should create a theft case", async function () {
    // Create a theft case
    await combinedTribunalNFT.createTheftCase(user2.address, user1.address, ethers.utils.parseEther("1"));
    const theftCase = await combinedTribunalNFT.theftCases(1);

    expect(theftCase.thief).to.equal(user2.address);
    expect(theftCase.victim).to.equal(user1.address);
    expect(theftCase.stolenAmount).to.equal(ethers.utils.parseEther("1"));
    expect(theftCase.resolved).to.equal(false);
  });

  it("Should resolve a theft case", async function () {
    // Create a theft case
    await combinedTribunalNFT.createTheftCase(user2.address, user1.address, ethers.utils.parseEther("1"));

    // Resolve the theft case
    await combinedTribunalNFT.resolveTheftCase(1);
    const theftCase = await combinedTribunalNFT.theftCases(1);

    expect(theftCase.resolved).to.equal(true);
  });

  // Add more tests for other functions as needed

});
