// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./IParameterControl.sol";
import "./IRove.sol";
import "./IMetaverseNFT.sol";
import "./IExperienceNFT.sol";
import "./IRockNFT.sol";
import './proxy/transparentUpgradeableProxy.sol';

/*
 * TODO:
 * [x] Minting
 * [x] Mint rock from 2 rocks? Aka. Breed a new rock.
 * [ ] Mint in batch?
 * [x] Rock attributes
 * [ ] Lease
 * [ ] Rock tax
 *
 */

contract RockNFT is ERC721Upgradeable {

        // TODO: do we save gas cost if we use uint8?
        struct Rock {

                uint256 metaverseId;
                uint256 dad;
                uint256 mom;

                // uint256 capacity; // the maximum number of Rovers the rock can host

                // // visual attributes
                // uint256 color; 
                // uint256 texture; 

                // // coordinate
                // uint256 x; 
                // uint256 y; 

                // // historical attributes
                // uint256 birthdate; // or birth block?
                // uint256 generation; // max(mom, dad) + 1

                // // special-effect attributes
                // uint256 gravity; // for VR experience, give Rovers the flying superpower 

                // the complexity of the rock. different complexity unlocks different experience types 
                // on the rock. if the i-th bit is on, that experience type is enabled on the rock.
                //
                // bit 0: audio
                // bit 1: video
                // bit 2: stream
                // bit 3: spatial
                // bit 4: vr
                // bit 5 and beyond: reserved for new experience types
                // 
                // for example:
                //
                // 1: 00000001 audio
                // 2: 00000010 video
                // 3: 00000011 audio + video
                // 4: 00000100 stream
                // 5: 00000101 stream + audio
                // 6: 00000110 stream + video
                // etc
                uint256 complexity;

                // rental fees by experience type
                // (experienceType, hosting fee)
                // mapping(uint256 => uint256) rentalFees;
                uint256[] timeSlots;
                uint256 rentalFee;
        }

        // struct Lease {
        //         address renter;
        //         uint256 from;
        //         uint256 to;
        //         uint256 base;
        //         uint256 revenueShare;
        // }

        using Counters for Counters.Counter;
        Counters.Counter private _counter;

        IParameterControl _globalParameters;
        IRove _rove;
        IMetaverseNFT _metaverseNFT;
        IExperienceNFT _experienceNFT;

        mapping(uint256 => Rock) private _rocks;
        // mapping(uint256 => Lease) private _leases;

        modifier onlyExperienceNFT() {
                require(_msgSender() == address(_experienceNFT), "only experience NFT");
                _;
        }

        modifier onlyMetaverseNFT() {
                require(_msgSender() == address(_metaverseNFT), "only metaverse NFT");
                _;
        }

        event UpdateRockFee(address, uint256, uint256);
        event ExperienceContractCreated(address contractId);

        // admin of rock is metaverse nft
        // constructor(
        //         IRove rove,
        //         IParameterControl globalParameters,
        //         IMetaverseNFT metaverseNFT
        // ) 
        //         ERC721("Rock", "R")
        // {
        //         _setupRole(DEFAULT_ADMIN_ROLE, address(metaverseNFT));
        //         _rove = rove;
        //         _globalParameters = globalParameters;
        //         _metaverseNFT = metaverseNFT;
        //         _experienceNFT = new ExperienceNFT(address(this), address(metaverseNFT), globalParameters, address(rove));

        //         emit ExperienceContractCreated(address(_experienceNFT));
        // }

        function initialize(IRove rove, IParameterControl globalParameters, IMetaverseNFT metaverseNFT, address experienceImpl, address implementationAdmin) initializer public {
                __ERC721_init("Rock", "R");
                _rove = rove;
                _globalParameters = globalParameters;
                _metaverseNFT = metaverseNFT;
                _experienceNFT = IExperienceNFT(address(new TransparentUpgradeableProxy(
                        address(experienceImpl), 
                        implementationAdmin, 
                        abi.encodeWithSignature('initialize(address,address,address,address)', address(this), address(metaverseNFT), address(globalParameters), address(rove))
                )));

                emit ExperienceContractCreated(address(_experienceNFT));
        }

        function mintRock(
                uint256 metaverseId, 
                address owner, 
                uint256 rentalFee
        )
                external
                onlyMetaverseNFT()
                returns (uint256)
        {
                _counter.increment();

                uint256 i = _counter.current();
                Rock storage r = _rocks[i];
                r.metaverseId = metaverseId;
                r.rentalFee = rentalFee;

                _mint(owner, i);

                return i;
        }

        // @dev given 2 rock parents, breed a new child rock
        // TODO: should we let N rock parents where N > 2?
        function breedRock(
                uint256 metaverseId, 
                address owner,
                uint256 dadId, 
                uint256 momId, 
                uint256 rentalFee
        ) 
                external 
                onlyMetaverseNFT()
                returns (uint256) 
        {
                require(ownerOf(dadId) == owner);
                require(ownerOf(momId) == owner);
                require(_rocks[dadId].metaverseId == metaverseId);
                require(_rocks[momId].metaverseId == metaverseId);

                _counter.increment();
                uint256 i = _counter.current();
                Rock storage child = _rocks[i];
                child.dad = dadId;
                child.mom = momId;
                child.rentalFee = rentalFee;
                // Rock storage dad = _rocks[dadId];
                // Rock storage mom = _rocks[momId];

                // child.capacity = _breed(dad.capacity, mom.capacity, "capacity");
                // child.x = _breed(dad.x, mom.x, "x");
                // child.y = _breed(dad.y, mom.y, "y");
                // child.gravity = _breed(dad.gravity, mom.gravity, "gravity");
                // child.color = _breed(dad.color, mom.color, "color");

                // TODO: breed and populate other attributes
                //
                //

                _mint(owner, i);

                return i;
        }

        /**
        * @dev check the event time is overlap
        */
        function addTimeSlot(uint256 start, uint256 end, uint256 rockId) external onlyExperienceNFT() {
                require(end > start, "invalid start and end time!");
                require(start - block.timestamp < 1 weeks, "can not book event in this time!"); 
                Rock memory rock = _rocks[rockId];
                uint256 r = rock.timeSlots.length;
                if (r == 0 || (rock.timeSlots[r - 1] < start)) {
                        _rocks[rockId].timeSlots.push(start);
                        _rocks[rockId].timeSlots.push(end);
                } else {
                        uint l = 0;
                        r = r - 1;
                        while (l != r) {
                                uint m = (l + r + 1) / 2;
                                if (start >= rock.timeSlots[m]) {
                                        l = m;
                                } else {
                                        r = m - 1;
                                }
                        }
                        string memory revertMsg = "this slot has been occupied!";
                        if (l % 2 == 1) {
                                require(start != rock.timeSlots[l] && rock.timeSlots[l + 1] > end, revertMsg);
                                l += 1;
                        } else {
                                require(l == 0 && rock.timeSlots[l] > end, revertMsg);
                        }
                        _rocks[rockId].timeSlots = insertAtIndex(l, start, end, rock.timeSlots);
                }
        }

        function insertAtIndex(uint256 index, uint256 start, uint256 end, uint256[] memory bookedTimes) pure internal returns(uint[] memory) {
                uint256[] memory newBookedTimes = new uint[](bookedTimes.length + 2);
                uint j = 0;
                for (uint i = 0; i < newBookedTimes.length;) {
                        if (i == index) {
                                newBookedTimes[i] = start;
                                newBookedTimes[i+1] = end;
                                i += 2;
                        }
                        newBookedTimes[i] = bookedTimes[j];
                        j++;
                        i++;
                }                

                return newBookedTimes;
        }

        function updateRentalFee(uint256 rockId, uint256 fee) external {
                require(msg.sender == ownerOf(rockId), "Rock NFT: only rock owner");
                _rocks[rockId].rentalFee = fee;

                emit UpdateRockFee(msg.sender, rockId, fee);
        }      

        // function hasAccess(address rover, uint256 rockId) external view returns (bool) {
        //         return (ownerOf(rockId) == rover) || (_leases[rockId].renter == rover);
        // }

        function getRentalFee(uint256 rockId) external view returns (uint256) {
                return _rocks[rockId].rentalFee;
        }

        function getRock(uint256 rockId) external view returns (Rock memory) {
                return _rocks[rockId];
        }

        function getMetaverseId(uint256 rockId) external view returns (uint256) {
                return _rocks[rockId].metaverseId;
        }    

        function getExperienceNFT() external view returns (address) {
                return address(_experienceNFT);
        }

        // TODO;
        // function insertTimeSlot() 

        // @dev a child is an offspring of mom and dad
        // TODO: move these parameters to Global Parameter contract so they can be adjusted via DAO
        // TODO: should we add a (+) operator here so Rover can combine 2 rocks to make a bigger one?
        // function _breed(uint256 dad, uint256 mom, string memory attribute) internal view returns (uint256) {

        //         uint256 offspring = _random(100, attribute, dad + mom);
        //         uint256 child;

        //         if (offspring < 50) {
        //                 // 50% chance the child a combination of mom and dad
        //                 uint256 dadWeight = _random(100, attribute, dad);
        //                 uint256 momWeight = _random(100, attribute, mom);
        //                 child = (dad * dadWeight + mom * momWeight) / (dadWeight + momWeight);
        //         } else if (offspring < 75) {
        //                 // 25% chance the child is exactly like dad
        //                 child = dad;
        //         } else {
        //                 // 25% chance the child is exactly like mom
        //                 child = mom;
        //         }

        //         uint256 mutation = _random(100, attribute, dad * mom);
        //         if (mutation < 5) {
        //                 // there is a 5% chance of having a 10% decrease mutation
        //                 child = child * 90 / 100;
        //         } else if (mutation < 10) {
        //                 // there is a 5% chance of having a 10% increase mutation
        //                 child = child * 110 / 100;
        //         }

        //         return child;
        // }

        // // @dev generate a random number between 0 and range
        // function _random(
        //         uint256 range, 
        //         string memory attribute, 
        //         uint256 value
        // ) 
        //         internal 
        //         view 
        //         returns (uint256) 
        // {
        //         bytes memory package = abi.encodePacked(block.difficulty, block.timestamp, attribute, value);
        //         uint256 randomHash = uint(keccak256(package));
        //         return randomHash % range;
        // }
}
