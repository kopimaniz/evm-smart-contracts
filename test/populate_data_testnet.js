const MetaverseNFT = artifacts.require("MetaverseNFT");
const Rove = artifacts.require("Rove");
const RockNFT = artifacts.require("RockNFT");
const TransparentUpgradeableProxy = artifacts.require("TransparentUpgradeableProxy");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
contract("Popular data", function (accounts) {
    const metaverseAddress = '0x05E01879bC38A0789fECF7922Ea38C120Cd61fb0';
    const rovoTokenAddress = '0xf87a690C4b6cbf7a8e320Fd1DC7e447E7E8a32b0';
    const rockNFTAddresss = '0xC137D5490CBCFADD75FDa76395344252c973ccAE';
    let metaverseNFT;
    let roveToken;
    let rockNFT;
    const testAddress = '0xD3605808CcdFd0e61515D53a0D2E13c3c9107505';
  
    before("should init instance of contracts", async function () {
      metaverseNFT = await MetaverseNFT.at(metaverseAddress);
      roveToken = await Rove.at(rovoTokenAddress);
      rockNFT = await RockNFT.at(rockNFTAddresss);
    });
  
    let revenue = [web3.utils.toBN(1e18), web3.utils.toBN(1e3), web3.utils.toBN(1e3)]; // 1e3 ~ 10%
    let defaultFee = web3.utils.toBN(1e18);
    let numberOfgenesisRock = 2;
    
    it('should mint the token', async () => {
      await roveToken.mint(testAddress, web3.utils.toBN(100e18));
      const value = await roveToken.balanceOf(testAddress);
      console.log(value.toString());
    });
  
    it('create new metaverse', async () => {
      await roveToken.approve(metaverseNFT.address, web3.utils.toBN('100000000000000000000'));
      await metaverseNFT.mintMetaverse(testAddress, testAddress, numberOfgenesisRock, defaultFee, revenue);
      await metaverseNFT.mintMetaverse(testAddress, testAddress, numberOfgenesisRock, defaultFee, revenue);
      const bal = await metaverseNFT.balanceOf(testAddress); 
      const globaDAOBal = await roveToken.balanceOf(testAddress);
      console.log(globaDAOBal.toString());
      console.log(bal.toString());
  
      assert.equal(-1, web3.utils.toBN(1).cmp(bal));
      assert.equal(-1, web3.utils.toBN(0).cmp(globaDAOBal));
      
      // check ownership
      const owner1 = await rockNFT.ownerOf(1);
      const owner2 = await rockNFT.ownerOf(2);
      const owner3 = await metaverseNFT.ownerOf(1);
  
      assert.equal(owner2, testAddress);
      assert.equal(owner1, testAddress);
      assert.equal(owner3, testAddress);
    });

});