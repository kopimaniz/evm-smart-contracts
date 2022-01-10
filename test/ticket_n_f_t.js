const MetaverseNFT = artifacts.require("MetaverseNFT");
const ExperienceNFT = artifacts.require("ExperienceNFT");
const RockNFT = artifacts.require("RockNFT");
const TicketNFT = artifacts.require("TicketNFT");
const truffleAssert = require('truffle-assertions');

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
contract("TicketNFT", function (accounts) {
  let metaverseNFT;
  let ticketNFT;
  let rockNFT;
  let experienceNFT;
  let ticketAddress;

  before("should init instance of contracts", async function () {
    metaverseNFT = await MetaverseNFT.deployed();
    const rockContractId = await metaverseNFT.getRockNFT();
    console.log({rockContractId});
    rockNFT = await RockNFT.at(rockContractId);
    const experienceContractId = await rockNFT.getExperienceNFT();
    console.log({experienceContractId});
    experienceNFT = await ExperienceNFT.at(experienceContractId);
    ticketAddress= await experienceNFT.getTicketNFT();
    console.log({ticketAddress});
    ticketNFT = await TicketNFT.at(ticketAddress);
  });

  it('should not equal to zero', async () => {
    assert.notEqual(ticketAddress, '0x0000000000000000000000000000000000000000');
  });

  it("should fail cause only experienceNFT can mint", async () => {
    await truffleAssert.reverts(ticketNFT.mintTicket(accounts[1], 'Im ticket 1', {
    from: accounts[1]
  }))});
});
