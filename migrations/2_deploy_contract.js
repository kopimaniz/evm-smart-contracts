const Migrations = artifacts.require("Migrations");
var fs = require('fs');
// NFTs
const MetaverseNFT = artifacts.require("MetaverseNFT");
const NameNFT = artifacts.require("NameNFT");
// these nft below will be deployed by metaverse contract
const RockNFT = artifacts.require("RockNFT");
const ExperienceNFT = artifacts.require("ExperienceNFT");
const TicketNFT = artifacts.require("TicketNFT");
// params
const ParameterControl = artifacts.require("ParameterControl");

// token
const Rove = artifacts.require("Rove");

// proxy 
const TransparentUpgradeableProxy = artifacts.require("TransparentUpgradeableProxy");
var Web3 = require('web3');
const web3 = new Web3();

// configurations
const adminDefault = "0xD3605808CcdFd0e61515D53a0D2E13c3c9107505";
const ROCK_BREEDING_FEE = '1000000000000000000';
const ROCK_RENTING_FEE = '1000000000000000000';
const ROCK_TIME_COST_UNIT = '3600';
const HOSTING_FEE = '1000';
const GLOBAL_ROVE_DAO = adminDefault;
const GLOBAL_SALES_TAX = '1000';

module.exports = async function(deployer, network, accounts) {
  if (network != 'development') {
     return;
  }
  // todo: update accordingly to the network
  const adminDefault = accounts[0];
  const adminImplementation = accounts[2];
  await deployer.deploy(Rove, adminDefault);
  const roveIns = await Rove.deployed();
  await deployer.deploy(NameNFT, adminDefault);
  const nameNFT = await NameNFT.deployed();
  await deployer.deploy(ParameterControl, adminDefault, ROCK_BREEDING_FEE, ROCK_RENTING_FEE, ROCK_TIME_COST_UNIT, HOSTING_FEE, GLOBAL_ROVE_DAO, GLOBAL_SALES_TAX);
  const parameterControlIns = await ParameterControl.deployed();
  
  // deploy metaverseNFT
  await deployer.deploy(MetaverseNFT);
  let metaverseNFTInst = await MetaverseNFT.deployed();
  await deployer.deploy(RockNFT);
  const rockNFTInst = await RockNFT.deployed();
  await deployer.deploy(ExperienceNFT);
  const expNFTInst = await ExperienceNFT.deployed();
  const abi = {
    "inputs": [
      {
        "internalType": "contract IParameterControl",
        "name": "globalParameters",
        "type": "address"
      },
      {
        "internalType": "contract IRove",
        "name": "rove",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "rockImpl",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "expImpl",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "implementationAdmin",
        "type": "address"
      }
    ],
    "name": "initialize",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  };
  const dataInistalized = web3.eth.abi.encodeFunctionCall(abi, [parameterControlIns.address, roveIns.address, rockNFTInst.address, expNFTInst.address, adminImplementation]);
  await deployer.deploy(TransparentUpgradeableProxy, metaverseNFTInst.address, adminImplementation, dataInistalized);
  const tranparent = await TransparentUpgradeableProxy.deployed();
  metaverseNFTInst = await MetaverseNFT.at(tranparent.address);

  const rockContractId = await metaverseNFTInst.getRockNFT();
  const rockNFT = await RockNFT.at(rockContractId);
  const experienceContractId = await rockNFT.getExperienceNFT();
  const experienceNFT = await ExperienceNFT.at(experienceContractId);
  const ticketAddress= await experienceNFT.getTicketNFT();
  const ticketNFT = await TicketNFT.at(ticketAddress);

  const listAddresses = `admin: ${adminDefault}\n` +
  `adminImplementation: ${adminImplementation}\n` +
  `rove token: ${roveIns.address} \n` +
  `global params: ${parameterControlIns.address} \n` +
  `nameNFT token: ${nameNFT.address} \n` +
  `metaverseNFT token ${metaverseNFTInst.address} \n` +
  `rockNFT token ${rockNFT.address} \n` +
  `experienceNFT token ${experienceNFT.address} \n` +
  `ticketNFT token ${ticketNFT.address} \n`;

  console.log({listAddresses});

  // write log to file
  fs.writeFile('./addresses.txt', listAddresses
  ,()=>{
    console.log('Successfully saved');
  })
}