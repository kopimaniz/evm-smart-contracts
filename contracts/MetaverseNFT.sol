// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./IParameterControl.sol";
import "./IRove.sol";
import "./IRockNFT.sol";
import "./utils/constants.sol";
import "./IMetaverseNFT.sol";
import './proxy/transparentUpgradeableProxy.sol';

/**
 * @dev Implementation of the Metaverse element in Rove
 *
 * Each metaverse comes with the first 100 rocks.
 *
 * TODO:
 * [x] Mint a metaverse
 * [x] Minting gensis rocks
 * [x] Revenue
 * [ ] Metaverse DAO
 *
 */

contract MetaverseNFT is ERC721Upgradeable, Constant {

        struct Metaverse {
                address metaverseDAO;
                Revenue revenue;
        }

        struct Revenue {
                uint256 breedingFee;
                uint256 salesTaxRate;
                uint256 propertyTaxRate;
        }

        using Counters for Counters.Counter;
        Counters.Counter private _counter;

        IParameterControl _globalParameters;
        IRove _rove;
        IRockNFT _rockNFT;

        mapping(uint256 => Metaverse) private _metaverses;

        modifier onlyOwner(uint256 metaverseId) {
                require(ownerOf(metaverseId) == msg.sender, "MetaverseNFT: not the founder");
                _;
        }

        event NewMetaverse(address owner, uint256 metaverseId, uint256[] rocks, uint256 defaultFee);
        event Breed(address owner, uint256 dadId, uint256 momId, uint256 rockId, uint256 metaverseId, uint256 rentalFee);
        event RockContractCreated(address contractId);

        // constructor(
        //         IParameterControl globalParameters,
        //         IRove rove
        // ) 
        //         ERC721("Metaverse", "M") 
        // {
        //         _globalParameters = globalParameters;
        //         _rove = rove;
        //         _rockNFT = new RockNFT(rove, globalParameters, IMetaverseNFT(address(this)));

        //         emit RockContractCreated(address(_rockNFT));
        // }
 
        function initialize(IParameterControl globalParameters, IRove rove, address rockImpl, address metaverseImpl, address implementationAdmin) initializer public {
                __ERC721_init("Metaverse", "M");
                _rove = rove;
                _globalParameters = globalParameters;
                _rockNFT = IRockNFT(address(new TransparentUpgradeableProxy(
                        rockImpl, 
                        implementationAdmin, 
                        abi.encodeWithSignature('initialize(address,address,address,address,address)', address(rove), address(globalParameters), address(this), metaverseImpl, implementationAdmin)
                )));

                emit RockContractCreated(address(_rockNFT));
        }

        function mintMetaverse(
                address founder,
                address metaverseDAO,
                uint256 numberOfGenesisRocks,
                uint256 defaultFee,
                Revenue memory revenue
        )
                external
                returns (uint256)
        {
                require(numberOfGenesisRocks > 1, "MetaverseNFT: at least 2 genesis rocks created");
                require(revenue.salesTaxRate < MAX_PERCENT && revenue.propertyTaxRate < MAX_PERCENT, "MetaverseNFT: invalid tax rates");
                _rove.transferFrom(_msgSender(), address(uint160(_globalParameters.get(GLOBAL_ROVE_DAO))), _globalParameters.get(ROCK_BREEDING_FEE) * numberOfGenesisRocks); 
                _counter.increment();
                uint256 i = _counter.current();

                Metaverse storage m = _metaverses[i];
                m.revenue = revenue;
                m.metaverseDAO = metaverseDAO;

                _mint(founder, i);
                uint[] memory rocks = new uint256[](numberOfGenesisRocks);
                for (uint256 j = 0; i < numberOfGenesisRocks; i++) {
                        rocks[j] = _rockNFT.mintRock(i, founder, defaultFee);
                }

                emit NewMetaverse(founder, i, rocks, defaultFee);
                return i;
        }

        // @dev given 2 rock parents, breed a new child rock
        // TODO: should we let N rock parents where N > 2?
        function breedRock(
                uint256 metaverseId, 
                uint256 dadId, 
                uint256 momId, 
                uint256 rentalFee
        ) 
                external 
                returns (uint256) 
        {
                require(dadId != momId);
                address owner = msg.sender;
                Metaverse storage m = _metaverses[metaverseId];
                if (_globalParameters.get(ROCK_BREEDING_FEE) > 0) {
                        _rove.transferFrom(owner, address(uint160(_globalParameters.get(GLOBAL_ROVE_DAO))), _globalParameters.get(ROCK_BREEDING_FEE));
                }
                uint256 metaverseBreedingFee = m.revenue.breedingFee;
                if (metaverseBreedingFee > 0) {
                        _rove.transferFrom(owner, m.metaverseDAO, metaverseBreedingFee);
                }

                uint256 childId = _rockNFT.breedRock(metaverseId, owner, dadId, momId, rentalFee);

                emit Breed(owner, dadId, momId, childId, metaverseId, rentalFee);
                return childId;
        }

        function setRevenue(uint256 metaverseId, Revenue memory revenue) external onlyOwner(metaverseId) {
                require(revenue.salesTaxRate < MAX_PERCENT && revenue.propertyTaxRate < MAX_PERCENT, "MetaverseNFT: invalid tax rates");
                _metaverses[metaverseId].revenue = revenue;
        }

        function getRevenue(uint256 metaverseId) external view returns(Revenue memory) {
                return _metaverses[metaverseId].revenue;
        }

        function getRockNFT() external view returns(address) {
                return address(_rockNFT);
        }

        function getMetaverseNFT(uint256 metaverseId) external view returns(Metaverse memory) {
                return _metaverses[metaverseId];
        }

        function getMetaverseDAO(uint256 metaverseId) external view returns(address) {
                return _metaverses[metaverseId].metaverseDAO;
        }
}
