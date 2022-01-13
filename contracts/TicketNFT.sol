// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TicketNFT is AccessControl, ERC721 {


        using Counters for Counters.Counter;
        Counters.Counter private _counter;

        constructor(address admin) ERC721("Ticket", "T") {
                _setupRole(DEFAULT_ADMIN_ROLE, admin);
        }

        // mapping experience with ticket
        mapping (uint256 => uint256) public tickets;

        function mintTicket(address rover, uint256 experienceId)
                public
                onlyRole(DEFAULT_ADMIN_ROLE)
                returns (uint256)
        {
                _counter.increment();

                uint256 i = _counter.current();
                _mint(rover, i);
                tickets[i] = experienceId;

                return i;
        }

        function supportsInterface(bytes4 interfaceId) 
                public 
                view 
                virtual 
                override(AccessControl, ERC721) 
                returns (bool) 
        { 
                return 
                        interfaceId == type(IERC721).interfaceId || 
                        interfaceId == type(IERC721Metadata).interfaceId || 
                        super.supportsInterface(interfaceId);
        }

}
