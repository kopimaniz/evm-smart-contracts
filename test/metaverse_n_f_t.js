const MetaverseNFT = artifacts.require("MetaverseNFT");
const Rove = artifacts.require("Rove");
const RockNFT = artifacts.require("RockNFT");
const truffleAssert = require('truffle-assertions');
const TransparentUpgradeableProxy = artifacts.require("TransparentUpgradeableProxy");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
contract("MetaverseNFT", function (accounts) {
  let metaverseNFT;
  let roveToken;
  let rockNFT;
  const MAX_ROCKS_IN_TX = 30;

  before("should init instance of contracts", async function () {
    const tranparent = await TransparentUpgradeableProxy.deployed();
    metaverseNFT = await MetaverseNFT.at(tranparent.address);
    roveToken = await Rove.deployed();
    const rockContractId = await metaverseNFT.getRockNFT();
    rockNFT = await RockNFT.at(rockContractId);
  });

  let revenue = [web3.utils.toBN(1e18), web3.utils.toBN(1e3), web3.utils.toBN(1e3)]; // 1e3 ~ 10%
  let defaultFee = web3.utils.toBN(1e18);
  let numberOfgenesisRock = 2;

  it("should fail", async () => {
    await truffleAssert.reverts(metaverseNFT.mintMetaverse(accounts[0], accounts[0], numberOfgenesisRock, defaultFee, revenue));
  });
  
  it('should mint the token', async () => {
    await roveToken.mint(accounts[0], web3.utils.toBN(100e18), {from: accounts[0]});
    const value = await roveToken.balanceOf(accounts[0]);
    const totalSupply = await roveToken.totalSupply();

    assert.equal(0, web3.utils.toBN(100e18).cmp(value));
    assert.equal(0, web3.utils.toBN(100e18).cmp(totalSupply));
  });

  it('create new metaverse', async () => {
    await roveToken.approve(metaverseNFT.address, web3.utils.toBN('100000000000000000000'), {from: accounts[0]});
    await metaverseNFT.mintMetaverse(accounts[0], accounts[0], numberOfgenesisRock, defaultFee, revenue);
    const bal = await metaverseNFT.balanceOf(accounts[0]); 
    const globaDAOBal = await roveToken.balanceOf("0xD3605808CcdFd0e61515D53a0D2E13c3c9107505");

    assert.equal(0, web3.utils.toBN(1).cmp(bal));
    assert.equal(-1, web3.utils.toBN(0).cmp(globaDAOBal));
    
    // check ownership
    const owner1 = await rockNFT.ownerOf(1);
    const owner2 = await rockNFT.ownerOf(2);
    const owner3 = await metaverseNFT.ownerOf(1);

    assert.equal(owner2, accounts[0]);
    assert.equal(owner1, accounts[0]);
    assert.equal(owner3, accounts[0]);
  });

  it('create new metaverse with genesisrock exceeded max rock', async () => {
    await roveToken.mint(accounts[2], web3.utils.toBN(100e18));
    await roveToken.approve(metaverseNFT.address, web3.utils.toBN('100000000000000000000'), {from: accounts[2]});
    await metaverseNFT.mintMetaverse(accounts[2], accounts[0], MAX_ROCKS_IN_TX + 1, defaultFee, revenue, {from: accounts[2]});
    const bal = await metaverseNFT.balanceOf(accounts[2]); 
    assert.equal(0, web3.utils.toBN(1).cmp(bal));

    let balRock = await rockNFT.balanceOf(accounts[2]); 
    assert.equal(0, web3.utils.toBN(MAX_ROCKS_IN_TX).cmp(balRock));

    // mint new genesis rock
    await truffleAssert.reverts(metaverseNFT.mintGenesisBlock(2, 2, defaultFee, {from: accounts[2]}));
    await truffleAssert.reverts(metaverseNFT.mintGenesisBlock(2, 1, defaultFee, {from: accounts[0]}));

    await metaverseNFT.mintGenesisBlock(2, 1, defaultFee, {from: accounts[2]});
    balRock = await rockNFT.balanceOf(accounts[2]); 
    assert.equal(0, web3.utils.toBN(MAX_ROCKS_IN_TX + 1).cmp(balRock));

    await truffleAssert.reverts(metaverseNFT.mintGenesisBlock(2, 1, defaultFee, {from: accounts[2]}));

  });

  it('breed two rocks', async () => {
    const roveBeforeBreed = await roveToken.balanceOf(accounts[0]);;
    const rockBeforeBreed = await rockNFT. balanceOf(accounts[0]); ;
    await truffleAssert.reverts(metaverseNFT.breedRock( 1, 1, 1, web3.utils.toBN(1e14), {from: accounts[0]}));
    await metaverseNFT.breedRock( 1, 1, 2, web3.utils.toBN(1e14), {from: accounts[0]})
    const roveAfterBreed = await roveToken.balanceOf(accounts[0]);;
    const rockAfterBreed = await rockNFT.balanceOf(accounts[0]); ;

    assert.equal(-1, roveAfterBreed.cmp(roveBeforeBreed));
    assert.equal(1, rockAfterBreed.cmp(rockBeforeBreed));
  });

  it("should fail", async () => {
    const newFee = web3.utils.toBN(1e14);
    await truffleAssert.reverts(rockNFT.updateRentalFee(1, newFee, {from: accounts[1]}));
  });

  it("rocker owner update rock rental fee", async () => {
    const newFee = web3.utils.toBN(2e14);
    await rockNFT.updateRentalFee(1, newFee, {from: accounts[0]});
    const fee = await rockNFT.getRentalFee(1);

    assert.equal(0, newFee.cmp(fee));
  });
});
