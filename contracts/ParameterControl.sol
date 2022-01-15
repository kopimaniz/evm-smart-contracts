// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/constants.sol";

/*
 * @dev Implementation of a programmable parameter control.
 *
 * [x] Add (key, value)
 * [x] Add access control 
 * [ ] Use string instead of uint256. Add a string to uint parser.
 *
 */

contract ParameterControl is Constant {

        address private _admin;
        mapping(string => uint256) private _params;

        constructor(
                address admin, 
                uint256 breedingFee, 
                uint256 rockRentingFee,
                uint256 costPerUnit,
                uint256 hostingFee,
                uint160 globalRoveDao,
                uint256 salesTax,
                uint256 maxRocks
        ) {
                _admin = admin;
                _params[ROCK_BREEDING_FEE] = breedingFee;
                _params[ROCK_RENTING_FEE] = rockRentingFee;
                _params[ROCK_TIME_COST_UNIT] = costPerUnit;
                _params[HOSTING_FEE] = hostingFee;
                _params[GLOBAL_ROVE_DAO] = globalRoveDao;
                _params[GLOBAL_SALES_TAX] = salesTax;
                _params[MAX_ROCKS_IN_TX] = maxRocks;
        }

        function get(string memory key) external view returns (uint256) {
                return _params[key];
        }

        function set(string memory key, uint256 value) external {
                require(msg.sender == _admin);
                _params[key] = value;
        }

        function updateAdmin(address admin) external {
                require(msg.sender == _admin);
                _admin = admin;
        }
}
