// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITicketNFT {

        function mintTicket(address to, uint256 experienceId) external returns (uint256);
        function ownerOf(uint256 tokenId) external view returns (address owner);

}
