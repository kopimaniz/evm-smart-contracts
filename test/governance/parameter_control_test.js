var {solidity} = require("ethereum-waffle");
var chai = require('chai');
chai.use(solidity);
const {ethers} = require("hardhat");
const expect = chai.expect;
const {addresses} = require("../constants");
const hardhatConfig = require("../../hardhat.config");
const {createAlchemyWeb3} = require("@alch/alchemy-web3");
const path = require("path");

function sleep(second) {
    return new Promise((resolve) => {
        setTimeout(resolve, second * 1000);
    });
}

describe("** NFTs erc-1155 contract", function () {
    let parameterControl;
    let parameterControlAddress;
    let admin_contract = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'; // default for local

    beforeEach(async function () {
        console.log("Hardhat network", hardhatConfig.defaultNetwork);
        let ParameterControlContract = await ethers.getContractFactory("ParameterControl");
        parameterControl = await ParameterControlContract.deploy(admin_contract);
        parameterControlAddress = parameterControl.address;
        console.log("ParameterControl deploy address", parameterControlAddress);
    });

    describe("* Check admin ", function () {
        it("- Check admin", async function () {
            let admin = await parameterControl.admin();
            console.log("expect admin: ", admin_contract);
            console.log("contract admin: ", admin);
            expect(admin).to.equal(admin_contract);
        });

        it("- Change admin", async function () {
            const changedAdmin = process.env.PUBLIC_KEY;
            await parameterControl.updateAdmin(changedAdmin);
            await sleep(3);
            console.log("expect admin: ", changedAdmin);
            let admin = await parameterControl.admin();
            console.log("contract admin: ", admin);
            expect(admin).to.equal(changedAdmin);
        });
    });

    describe("* Get/Set with admin ", function () {
        it("- Get/Set with old admin ", async function () {
            const temp = {
                "key": 'NFT_MINTER_PERCENT_PROFIT',
                "value": "10"
            };
            await parameterControl.set(temp.key, temp.value);
            await sleep(3);
            const value = await parameterControl.get(temp.key);
            expect(value).to.equal(temp.value);
        });
        it("- Get/Set with new admin ", async function () {
            const changedAdmin = "0x70997970c51812dc3a010c7d01b50e0d17dc79c8";
            const changedAdminPrivateKey = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d';
            await parameterControl.updateAdmin(changedAdmin);
            await sleep(3);
            console.log("expect admin: ", changedAdmin);
            let admin = await parameterControl.admin();
            console.log("contract admin: ", admin);
            // expect(admin).to.equal(changedAdmin);

            // set
            const temp = {
                "key": 'NFT_MINTER_PERCENT_PROFIT',
                "value": "10"
            };
            let contract = require(path.resolve("./artifacts/contracts/governance/ParameterControl.sol/ParameterControl.json"));
            const web3 = createAlchemyWeb3(hardhatConfig.networks[hardhatConfig.defaultNetwork].url);
            const parameterControl1 = new web3.eth.Contract(contract.abi, parameterControlAddress);
            const nonce = await web3.eth.getTransactionCount(changedAdmin, "latest") //get latest nonce
            const tx = {
                from: changedAdmin,
                to: parameterControlAddress,
                nonce: nonce,
                gas: 500000,
                data: parameterControl1.methods.set(temp.key, temp.value).encodeABI(),
            }
            const signedTx = await web3.eth.accounts.signTransaction(tx, changedAdminPrivateKey);
            if (signedTx.rawTransaction != null) {
                await web3.eth.sendSignedTransaction(signedTx.rawTransaction);
            }
            await sleep(3);

            // get
            let value = await parameterControl.get(temp.key);
            expect(value).to.equal(temp.value);
        });
    });
});
