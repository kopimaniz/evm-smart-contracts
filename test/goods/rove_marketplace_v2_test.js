var { solidity } = require("ethereum-waffle");
var chai = require("chai");
chai.use(solidity);
const { ethers } = require("hardhat");
const expect = chai.expect;
const { addresses } = require("../constants");
const hardhatConfig = require("../../hardhat.config");
const path = require("path");
const { createAlchemyWeb3 } = require("@alch/alchemy-web3");

function sleep(second) {
  return new Promise(resolve => {
    setTimeout(resolve, second * 1000);
  });
}

describe("Marketplace contract", function () {
  let roveToken;
  let roveTokenAdmin = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
  let roveTokenContractAddress;
  let decimals;

  let objectNFT;
  let objectNFTAddress;
  let tokenID;
  const initSupply = 10;
  const nftOwner = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
  const buyer = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"; // default for local
  const buyerPrivateKey =
    "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
  const buyerBalance = 1000000000; // transfer all 1 bil token to buyer

  let paramControl;
  let paramControlAddress;
  const CREATOR_BENEFIT = 1;
  const MARKET_BENEFIT = 2;

  let roveMarketplace;
  let roveMarketplaceAddress;
  const operator_address = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"; // default for local
  const operator_privatekey =
    "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a";

  beforeEach(async function () {
    // deploy rove token
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    let roveTokenContract = await ethers.getContractFactory("RoveToken");
    roveToken = await roveTokenContract.deploy(roveTokenAdmin);
    roveTokenContractAddress = roveToken.address;
    console.log("Rove token contract address", roveTokenContractAddress);
    decimals = await roveToken.decimals();
    decimals = 10 ** decimals;
    roveToken.transfer(buyer, buyerBalance * decimals); // transfer all 1 bil token to buyer

    // deploy nft
    let ObjectNFTContract = await ethers.getContractFactory("ObjectNFT");
    objectNFT = await ObjectNFTContract.deploy(roveTokenAdmin, roveTokenAdmin);
    objectNFTAddress = objectNFT.address;
    console.log("ObjectNFTDeploy address", objectNFTAddress);
    // mint nft
    let tokenURI =
      "https://gateway.pinata.cloud/ipfs/QmWYZQzeTHDMGcsUMgdJ64hgLrXk8iZKDRmbxWha4xdbbH";
    await objectNFT.createNFT(nftOwner, initSupply, tokenURI);
    tokenID = await objectNFT.newItemId();

    // deploy param
    let param = await ethers.getContractFactory("ParameterControl");
    paramControl = await param.deploy(roveTokenAdmin);
    paramControlAddress = paramControl.address;
    console.log("Paran control contract address", paramControlAddress);
    await paramControl.setUInt256("CREATOR_BENEFIT", CREATOR_BENEFIT);

    // deploy market
    let marketContract = await ethers.getContractFactory("RoveMarketPlaceV2");
    roveMarketplace = await marketContract.deploy(
      operator_address,
      roveTokenContractAddress,
      paramControlAddress
    );
    roveMarketplaceAddress = roveMarketplace.address;
    console.log("Rove Market place contract address", roveMarketplaceAddress);
  });

  describe("** Deployment Rove Market place", function () {
    it("* Should set the right operator", async function () {
      expect(await roveMarketplace.operator()).to.equal(operator_address);
    });

    it("* Should set the right rove token", async function () {
      expect(await roveMarketplace.roveToken()).to.equal(
        roveTokenContractAddress
      );
    });
  });

  describe("** Offering", function () {
    it("* Place offering", async function () {
      // nftOwner approve for market place contract
      let tx = await objectNFT.setApprovalForAll(roveMarketplaceAddress, true);
      let receipt = await tx.wait();
      let events = receipt.events?.filter(x => {
        return x.event == "ApprovalForAll";
      });
      expect(events.length).to.equal(1);
      expect(events[0].args[0]).to.equal(nftOwner);
      expect(events[0].args[1]).to.equal(roveMarketplaceAddress);
      expect(events[0].args[2]).to.equal(true);

      // place offering
      const priceOffer = 5 * decimals;
      const amountPlaceOffer = 3;
      tx = await roveMarketplace.placeOffering(
        objectNFTAddress,
        tokenID,
        roveTokenContractAddress,
        priceOffer,
        amountPlaceOffer
      );
      receipt = await tx.wait();
      events = receipt.events?.filter(x => {
        return x.event == "OfferingPlaced";
      });
      expect(events.length).to.equal(1);
      const offeringId = events[0].args[0];
      const hostContract = events[0].args[1];
      const offerer = events[0].args[2];
      const tokenId1 = events[0].args[3];
      const price = events[0].args[4];
      const uri = events[0].args[5];
      expect(hostContract).to.equal(objectNFTAddress);
      expect(offerer).to.equal(nftOwner);
      expect(tokenId1).to.equal(tokenID);
      expect(price).to.equal(priceOffer);

      // view offering
      let offerings = await roveMarketplace.arrayOffering();
      console.log("********", offerings, offeringId);
      expect(offeringId).to.equal(offerings[0]);
      hostContract,
        tokenId1,
        price,
        (closed = await roveMarketplace.viewOfferingNFT(offeringId));
      console.log("closed: ", closed);
      expect(hostContract).to.equal(objectNFTAddress);
      expect(tokenId1).to.equal(tokenID);
      expect(price).to.equal(priceOffer);
    });

    it("* Test place offering exceed innit suplly", async function () {
      // nftOwner approve for market place contract
      let tx = await objectNFT.setApprovalForAll(roveMarketplaceAddress, true);
      let receipt = await tx.wait();
      let events = receipt.events?.filter(x => {
        return x.event == "ApprovalForAll";
      });
      expect(events.length).to.equal(1);
      expect(events[0].args[0]).to.equal(nftOwner);
      expect(events[0].args[1]).to.equal(roveMarketplaceAddress);
      expect(events[0].args[2]).to.equal(true);
      // place offering
      const priceOffer = 5 * decimals;
      const amountPlaceOffer = 11;
      try {
        await roveMarketplace.placeOffering(
          objectNFTAddress,
          tokenID,
          roveTokenContractAddress,
          priceOffer,
          amountPlaceOffer
        );
      } catch (error) {
        expect(error.toString()).to.include(
          "NFT owner not enough balance erc-1155"
        );
      }
    });

    it("* Test Place offering without approve for marketplace", async function () {
      // place offering
      const priceOffer = 5 * decimals;
      const amountPlaceOffer = 3;
      try {
        await roveMarketplace.placeOffering(
          objectNFTAddress,
          tokenID,
          roveTokenContractAddress,
          priceOffer,
          amountPlaceOffer
        );
      } catch (error) {
        expect(error.toString()).to.include(
          "this contract address is not approved"
        );
      }
    });

    it("* Stop offering", async function () {
      let contract = require(path.resolve(
        "./artifacts/contracts/goods/RoveMarketPlaceV2.sol/RoveMarketPlaceV2.json"
      ));
      let contractToken = require(path.resolve(
        "./artifacts/contracts/monetary/RoveToken.sol/RoveToken.json"
      ));
      const web3 = createAlchemyWeb3(
        hardhatConfig.networks[hardhatConfig.defaultNetwork].url
      );
      const marketplace1 = new web3.eth.Contract(
        contract.abi,
        roveMarketplaceAddress
      );
      const roveToken1 = new web3.eth.Contract(
        contractToken.abi,
        roveTokenContractAddress
      );

      // nftOwner approve for market place contract
      let tx = await objectNFT.setApprovalForAll(roveMarketplaceAddress, true);
      let receipt = await tx.wait();
      let events = receipt.events?.filter(x => {
        return x.event == "ApprovalForAll";
      });
      expect(events.length).to.equal(1);
      expect(events[0].args[0]).to.equal(nftOwner);
      expect(events[0].args[1]).to.equal(roveMarketplaceAddress);
      expect(events[0].args[2]).to.equal(true);

      // nftOwner place offering with price 5 rove token
      const priceOffer = 5 * decimals;
      const amountPlaceOffer = 3;
      tx = await roveMarketplace.placeOffering(
        objectNFTAddress,
        tokenID,
        roveTokenContractAddress,
        priceOffer,
        amountPlaceOffer
      );
      receipt = await tx.wait();
      events = receipt.events?.filter(x => {
        return x.event == "OfferingPlaced";
      });
      expect(events.length).to.equal(1);
      const offeringId = events[0].args[0];

      // buyer approve for market place contract as spender
      const amountCloseOffer = amountPlaceOffer; // 3
      let nonce = await web3.eth.getTransactionCount(buyer, "latest"); //get latest nonce
      tx = {
        from: buyer,
        to: roveTokenContractAddress,
        nonce: nonce,
        gas: 500000,
        data: roveToken1.methods
          .approve(roveMarketplaceAddress, priceOffer * amountCloseOffer)
          .encodeABI(),
      };
      let signedTx = await web3.eth.accounts.signTransaction(
        tx,
        buyerPrivateKey
      );
      if (signedTx.rawTransaction != null) {
        await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
      }

      // buyer close order
      nonce = await web3.eth.getTransactionCount(buyer, "latest"); //get latest nonce
      tx = {
        from: buyer,
        to: roveMarketplaceAddress,
        nonce: nonce,
        gas: 500000,
        data: marketplace1.methods
          .closeOffering(offeringId, amountCloseOffer)
          .encodeABI(),
      };
      signedTx = await web3.eth.accounts.signTransaction(tx, buyerPrivateKey);
      if (signedTx.rawTransaction != null) {
        await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
      }
      const creatorBenefit =
        ((priceOffer * amountCloseOffer) / 100) * CREATOR_BENEFIT;

      console.log("creator benifit: ", creatorBenefit);
      // check balance
      const marketBalanceRoveToken = await roveToken.balanceOf(
        roveMarketplaceAddress
      );
      console.log("marketBalanceRoveToken: ", marketBalanceRoveToken);

      expect(marketBalanceRoveToken).to.equal(priceOffer * amountCloseOffer);
      let nftOwnerBalanceRoveTokenOnMarket = await roveMarketplace.viewBalances(
        nftOwner
      );
      console.log(
        "nftOwnerBalanceRoveTokenOnMarket: ",
        nftOwnerBalanceRoveTokenOnMarket
      );

      if (nftOwner != roveTokenAdmin) {
        expect(nftOwnerBalanceRoveTokenOnMarket).to.equal(
          priceOffer * amountCloseOffer - creatorBenefit
        );
      } else {
        expect(nftOwnerBalanceRoveTokenOnMarket).to.equal(
          priceOffer * amountCloseOffer
        );
      }
      const buyerBalanceRoveToken = await roveToken.balanceOf(buyer);
      expect(buyerBalanceRoveToken).to.equal(
        buyerBalance * decimals - priceOffer * amountCloseOffer
      );

      let nftOwnerBalanceNFT = await objectNFT.balanceOf(nftOwner, tokenID);
      expect(nftOwnerBalanceNFT).to.equal(initSupply - amountCloseOffer);
      const buyerBalanceNFT = await objectNFT.balanceOf(buyer, tokenID);
      expect(buyerBalanceNFT).to.equal(amountCloseOffer);
      expect(nftOwnerBalanceNFT.add(buyerBalanceNFT)).to.equal(initSupply);

      // call withdraw for owner nft for get rove token
      tx = await roveMarketplace.withdrawBalance();
      await tx.wait();
      // view balance market place again
      nftOwnerBalanceRoveTokenOnMarket = await roveMarketplace.viewBalances(
        nftOwner
      );
      expect(nftOwnerBalanceRoveTokenOnMarket).to.equal(0);
      // check erc-20 balance
      const nftOwnerWithdrawBalance = await roveToken.balanceOf(nftOwner);
      console.log(nftOwnerWithdrawBalance);
      if (nftOwner != roveTokenAdmin) {
        expect(nftOwnerWithdrawBalance).to.equal(
          priceOffer * amountCloseOffer - creatorBenefit
        );
      } else {
        expect(nftOwnerWithdrawBalance).to.equal(priceOffer * amountCloseOffer);
      }
    });
  });
});
