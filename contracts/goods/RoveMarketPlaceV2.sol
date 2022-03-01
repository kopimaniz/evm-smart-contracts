// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

import "../utils/ERC1155Tradable.sol";
import "../governance/ParameterControl.sol";

contract RoveMarketPlaceV2 {
    using SafeMath for uint; //
    using Counters for Counters.Counter;
    Counters.Counter private _offeringNonces;

    event OfferingPlaced(bytes32 indexed offeringId, address indexed hostContract, address indexed offerer, uint tokenId, uint price, string uri);
    event OfferingClosed(bytes32 indexed offeringId, address indexed buyer);
    event OfferingRemain(bytes32 indexed offeringId, address indexed buyer, uint indexed amount);
    event BalanceWithdrawn (address indexed beneficiary, uint amount);
    event OperatorChanged (address previousOperator, address newOperator);
    event ApprovalForAll(address owner, address operator, bool approved);

    address private _operator;
    address private _roveToken; // require using this erc-20 token in this market
    address private _parameterControl;

    mapping(address => uint) private _balances;

    struct profit {
        uint256 profitPecentCreator;
        uint256 profitCreator;
        uint256 profitPecentOperator;
        uint256 profitOperator;
        uint256 originPrice;
    }

    struct offering {
        address offerer;
        address hostContract;
        uint tokenId;
        uint price;
        uint amount;
        bool closed;
    }

    struct closeOfferingData {
        address buyer;
        uint price;
        uint totalPrice;
        uint256 balanceBuyer;
        uint256 approvalToken;
    }

    mapping(bytes32 => offering) offeringRegistry;
    bytes32[] private _arrayOffering;

    constructor (address operator_, address roveToken_, address parameterControl_) {
        console.log("Deploy Rove market place operator %s, rove token %s", operator_, roveToken_);
        _operator = operator_;
        _roveToken = roveToken_;
        _parameterControl = parameterControl_;
    }

    function operator() public view returns (address) {
        return _operator;
    }

    function roveToken() public view returns (address) {
        return _roveToken;
    }

    function arrayOffering() public view returns (bytes32[] memory) {
        return _arrayOffering;
    }

    function toHex16(bytes16 data) internal pure returns (bytes32 result) {
        result = bytes32(data) & 0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000 |
        (bytes32(data) & 0x0000000000000000FFFFFFFFFFFFFFFF00000000000000000000000000000000) >> 64;
        result = result & 0xFFFFFFFF000000000000000000000000FFFFFFFF000000000000000000000000 |
        (result & 0x00000000FFFFFFFF000000000000000000000000FFFFFFFF0000000000000000) >> 32;
        result = result & 0xFFFF000000000000FFFF000000000000FFFF000000000000FFFF000000000000 |
        (result & 0x0000FFFF000000000000FFFF000000000000FFFF000000000000FFFF00000000) >> 16;
        result = result & 0xFF000000FF000000FF000000FF000000FF000000FF000000FF000000FF000000 |
        (result & 0x00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000) >> 8;
        result = (result & 0xF000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000) >> 4 |
        (result & 0x0F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F00) >> 8;
        result = bytes32(0x3030303030303030303030303030303030303030303030303030303030303030 +
        uint256(result) +
            (uint256(result) + 0x0606060606060606060606060606060606060606060606060606060606060606 >> 4 &
            0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) * 7);
    }

    function toHex(bytes32 data) private pure returns (string memory) {
        return string(abi.encodePacked("0x", toHex16(bytes16(data)), toHex16(bytes16(data << 128))));
    }

    // NFTs's owner place offering
    function placeOffering(address _hostContract, uint _tokenId, uint _price, uint _amount) external {
        // owner nft is sender
        address nftOwner = msg.sender;
        // get hostContract of erc-1155
        ERC1155Tradable hostContract = ERC1155Tradable(_hostContract);
        uint256 nftBalance = hostContract.balanceOf(nftOwner, _tokenId);
        console.log("nftOwner balance: ", nftBalance);
        bool approval = hostContract.isApprovedForAll(nftOwner, address(this));

        /// check require
        // require(msg.sender == _operator, "Only operator dApp can create offerings");
        // check available amount of erc-1155
        require(nftBalance >= _amount, "NFT owner not enough balance erc-1155");
        // check approval of erc-1155 on this contract
        require(approval == true, "this contract address is not approved");

        // create offering nonce by counter
        _offeringNonces.increment();
        uint256 newItemId = _offeringNonces.current();
        console.log("create offering nonce by counter: ", newItemId);

        // init offering id
        bytes32 offeringId = keccak256(abi.encodePacked(newItemId, _hostContract, _tokenId));
        // create offering by id
        offeringRegistry[offeringId].offerer = nftOwner;
        offeringRegistry[offeringId].hostContract = _hostContract;
        offeringRegistry[offeringId].tokenId = _tokenId;
        offeringRegistry[offeringId].price = _price;
        offeringRegistry[offeringId].amount = _amount;
        console.log("init offeringId: %s", toHex(offeringId));

        string memory uri = hostContract.uri(_tokenId);
        _arrayOffering.push(offeringId);
        emit OfferingPlaced(offeringId, _hostContract, nftOwner, _tokenId, _price, uri);
    }

    function closeOffering(bytes32 _offeringId, uint _amount) external payable {
        // buyer is sender
        ERC20 token = ERC20(_roveToken);

        closeOfferingData memory _temp = closeOfferingData(
            msg.sender,
            offeringRegistry[_offeringId].price,
            offeringRegistry[_offeringId].price.mul(_amount),
            token.balanceOf(msg.sender),
            token.allowance(msg.sender, address(this))
        );

        console.log("get price of offering: %s", _temp.price);
        console.log("get total price of offering: %s", _temp.totalPrice);
        console.log("get balance erc-20 token of buyer %s: %s", _temp.buyer, _temp.balanceBuyer);

        // get offer
        address hostContractOffering = offeringRegistry[_offeringId].hostContract;
        ERC1155Tradable hostContract = ERC1155Tradable(hostContractOffering);
        uint tokenID = offeringRegistry[_offeringId].tokenId;
        address offerer = offeringRegistry[_offeringId].offerer;

        // check require
        require(_temp.approvalToken == _temp.totalPrice, "this contract address is not approved for spending erc-20");
        require(hostContract.balanceOf(offerer, tokenID) >= _amount, "Not enough token erc-1155 to sell");
        require(_temp.balanceBuyer >= _temp.totalPrice, "Buyer not enough funds erc-20 to buy");
        require(offeringRegistry[_offeringId].closed != true, "Offering is closed");

        // transfer erc-1155
        console.log("prepare safeTransferFrom offerer %s by this address %s", offerer, address(this));
        // only transfer one in this version
        hostContract.safeTransferFrom(offerer, _temp.buyer, tokenID, _amount, "0x");
        console.log("safeTransferFrom erc-1155 tokenID %s from %s to buyer %s",
            tokenID,
            offerer,
            _temp.buyer
        );

        // logic for 
        // profit of operator here
        ParameterControl parameterController = ParameterControl(_parameterControl);
        profit memory _profit = profit(0, 0, 0, 0, _temp.totalPrice);
        _profit.profitPecentOperator = parameterController.getUInt256("MARKET_PROFIT");
        if (_profit.profitPecentOperator > 0) {
            _profit.profitOperator = _profit.originPrice.div(100).mul(_profit.profitPecentOperator);
            _temp.totalPrice -= _profit.profitOperator;
            console.log("market operator profit %s", _profit.profitOperator);
            // update balance(on market) of operator
            _balances[_operator] += _profit.profitOperator;
        }
        // profit of minter nfts here
        _profit.profitPecentCreator = parameterController.getUInt256("CREATOR_PROFIT");
        if (_profit.profitPecentCreator > 0) {
            _profit.profitCreator = _profit.originPrice.div(100).mul(_profit.profitPecentCreator);
            _temp.totalPrice -= _profit.profitCreator;
            console.log("creator profit %s", _profit.profitCreator);
            // update balance(on market) of creator erc-1155
            address creator = hostContract.getCreator(tokenID);
            _balances[creator] += _profit.profitCreator;
        }

        // tranfer erc-20 token to this market contract
        console.log("tranfer erc-20 token %s to this market contract %s with amount: %s", _temp.buyer, address(this), _temp.totalPrice);
        token.transferFrom(_temp.buyer, address(this), _temp.totalPrice);
        offeringRegistry[_offeringId].amount -= _amount;

        // update balance(on market) of offerer
        console.log("update balance of offerer: %s +%s", offerer, _temp.totalPrice);
        _balances[offerer] += _temp.totalPrice;

        // close offering
        uint remainAmount = offeringRegistry[_offeringId].amount;
        if (remainAmount == 0) {
            offeringRegistry[_offeringId].closed = true;
            console.log("close offering: ", toHex(_offeringId));
            emit OfferingClosed(_offeringId, _temp.buyer);
        } else {
            console.log("remain amount of offering %s:%s", toHex(_offeringId), remainAmount);
            emit OfferingRemain(_offeringId, _temp.buyer, remainAmount);
        }
    }

    function withdrawBalance() external {
        address withdrawer = msg.sender;
        // check require: balance of sender in market place > 0
        console.log("balance of sender: ", _balances[withdrawer]);
        require(_balances[withdrawer] > 0, "You don't have any balance to withdraw");

        ERC20 token = ERC20(_roveToken);
        uint256 balance = token.balanceOf(address(this));
        console.log("balance of market place: ", balance);
        // check require balance of this market contract > sender's withdraw
        require(balance >= _balances[withdrawer], "Not enough balance for withdraw");


        // tranfer erc-20 token from this market contract to sender
        uint amount = _balances[withdrawer];
        //payable(withdrawer).transfer(amount);
        console.log("tranfer erc-20 %s from this market contract %s to sender %s", _roveToken, address(this), withdrawer);
        token.transfer(withdrawer, amount);

        // reset balance
        _balances[withdrawer] = 0;
        //        roveToken.approve(withdrawer, _balances[withdrawer]);

        emit BalanceWithdrawn(withdrawer, amount);
    }

    function changeOperator(address _newOperator) external {
        require(msg.sender == _operator, "only the operator can change the current operator");
        address previousOperator = _operator;
        _operator = _newOperator;
        emit OperatorChanged(previousOperator, _operator);
    }

    function viewOfferingNFT(bytes32 _offeringId) external view returns (address, uint, uint, bool, uint){
        return (offeringRegistry[_offeringId].hostContract,
        offeringRegistry[_offeringId].tokenId,
        offeringRegistry[_offeringId].price,
        offeringRegistry[_offeringId].closed,
        offeringRegistry[_offeringId].amount
        );
    }

    function viewBalances(address _address) external view returns (uint) {
        return (_balances[_address]);
    }

    function closeOfferingNFT(bytes32 _offeringId) external {
        require(msg.sender == _operator, "Only operator dApp can close offerings");

        address hostContractOffering = offeringRegistry[_offeringId].hostContract;
        ERC1155Tradable hostContract = ERC1155Tradable(hostContractOffering);
        uint tokenID = offeringRegistry[_offeringId].tokenId;
        address offerer = offeringRegistry[_offeringId].offerer;
        uint amount = offeringRegistry[_offeringId].amount;

        if (hostContract.balanceOf(offerer, tokenID) <= amount) {
            offeringRegistry[_offeringId].closed = true;
            emit OfferingClosed(_offeringId, address(0));
        }
    }
}