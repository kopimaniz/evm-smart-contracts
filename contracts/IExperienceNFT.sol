// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExperienceNFT {

        // Mints a new experience. The host must pay a rental fee to rock owner. 
        // Caller: Platform 
        function mintExperience(
                uint256 rockId,
                uint256 price,
                uint256 start,
                uint256 end,
                uint256 totalTickets
        ) external returns (uint256 experienceId);

        // Updates the ownership of multiple creators
        // Caller: Host, Platform
        function updateCreators(
                uint256 experienceId, 
                address[] memory creators, 
                uint256[] memory shares
        ) external;

        // Gets ticket
        // Caller: Audience, Plaform
        function getTicket(uint256 experienceId) external;

        // Ends an experience
        // Caller: Host, Platform
        function endExperience(uint256 experienceId) external;

        // Collects payment
        // Caller: Creator, Platform
        function collectPayment(uint256 experienceId) external;
        function getTicketNFT() external view returns (address);
        function setPrice(uint256 experienceId, uint256 price) external;
        // Events
        event UpdateCreators(uint256 experienceId, address[] creators, uint256[] shares);
        event NewExperience(uint256 experienceId, uint256 start, uint256 end, uint256 rockId, address host);
        event CollectPayment(uint256 experienceId, address creator, uint256 amount);
        event NewTicket(uint256 experienceId, address buyer, uint256 ticketId);
        event UpdateTicketPrice(uint256 experienceId, uint256 price);
        event TicketNFTCreated(address);
}
