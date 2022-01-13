// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetaverseNFT {

        struct Revenue {
                uint256 breedingFee;
                uint256 salesTaxRate;
                uint256 propertyTaxRate;
        }

        struct Metaverse {
                address metaverseDAO;
                Revenue revenue;
        }

        // Mints a new metaverse. Rover must pay minting fee.
        // Caller: Platform
        function mintMetaverse(
                address founder,
                address metaverseDAO,
                uint256 numberOfGenesisRocks,
                uint256 defaultFee,
                Revenue memory revenue
        ) external returns (uint256 metaverseId);

        // Breeds a new rock. Rover must pay a breeding fee.
        // Caller: Platform
        function breedRock(
                uint256 metaverseId, 
                uint256 dadId, 
                uint256 momId, 
                uint256 rentalFee
        ) external returns (uint256 childId);

        // Getters
        // function getRocks(uint256 metaversId) external view returns (uint256[] memory);
        // function getSalesTaxRate(uint256 metaversId) external view returns (uint256);
        // function getPropertyTaxRate(uint256 metaversId) external view returns (uint256);
        // function getKickstartReward(uint256 metaversId) external view returns (uint256);
        // function getCreatorReward(uint256 metaversId) external view returns (uint256);
        // function getAudienceReward(uint256 metaversId) external view returns (uint256);
        // function getBreedingFee(uint256 metaversId) external view returns (uint256);
        function getRevenue(uint256 metaverseId) external view returns(Revenue memory);
        function getRockNFT() external view returns(address);
        function getMetaverseNFT(uint256 metaverseId) external view returns(Metaverse memory);
        function getMetaverseDAO(uint256 metaverseId) external view returns(address);

        // // Setters
        // function setSalesTaxRate(uint256 metaversId, uint256 salesTaxRate) external;
        // function setPropertyTaxRate(uint256 metaversId, uint256 propertyTaxRate) external;
        // function setKickstartReward(uint256 metaversId, uint256 kickstartReward) external;
        // function setCreatorReward(uint256 metaversId, uint256 creatorReward) external; 
        // function setAudienceReward(uint256 metaversId, uint256 audienceReward) external;
        // function setBreedingFee(uint256 metaversId, uint256 breedingFee) external; 
        function setRevenue(uint256 metaverseId, Revenue memory revenue) external;

        // Events
        event NewMetaverse(address owner, uint256 metaverseId, uint256[] rocks, uint256 defaultFee);
        event Breed(address owner, uint256 dadId, uint256 momId, uint256 rockId, uint256 metaverseId, uint256 rentalFee);
        event RockContractCreated(address contractId);
}
