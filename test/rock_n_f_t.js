const RockNFT = artifacts.require("RockNFT");
const MetaverseNFT = artifacts.require("MetaverseNFT");
const truffleAssert = require('truffle-assertions');
var Web3 = require('web3');
const web3 = new Web3();
const TransparentUpgradeableProxy = artifacts.require("TransparentUpgradeableProxy");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
contract("RockNFT", function (accounts) {
  let metaverseNFT;
  let rockNFT;
  let rockContractId;

  before("should init instance of contracts", async function () {
    const tranparent = await TransparentUpgradeableProxy.deployed();
    metaverseNFT = await MetaverseNFT.at(tranparent.address);
    rockContractId = await metaverseNFT.getRockNFT();
    console.log({rockContractId});
    rockNFT = await RockNFT.at(rockContractId);
  });

  it('should not equal to zero', async () => {
    assert.notEqual(rockContractId, '0x0000000000000000000000000000000000000000');
  });

  it("Can not mint rock only metaverseNFT can do", async () => {
    await truffleAssert.reverts(rockNFT.mintRock(1, accounts[0], web3.utils.toBN(1e18),  {
    from: accounts[1]
  }))});

  it("Can not breed rock cause only metaverseNFT can do", async () => {
    await truffleAssert.reverts(rockNFT.breedRock(1, accounts[0], 1, 1, web3.utils.toBN(1e18),  {
    from: accounts[1]
  }))});

  it("Can not add time slot cause only experienceNFT can do", async () => {
    await truffleAssert.reverts(rockNFT.addTimeSlot(Math.floor(Date.now() / 1000) + 200, Math.floor(Date.now() / 1000) + 500, 1,  {
    from: accounts[1]
  }))});

  it("only owner can updat rental fee", async () => {
    await truffleAssert.reverts(rockNFT.updateRentalFee(1, web3.utils.toBN(1e18),  {
    from: accounts[1]
  }))});
});
