// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

contract EnergyTrading {
    address public owner;

    struct EnergyListing {
        address seller;
        uint256 amountKwh;
        uint256 costPerKwh;
    }
    
}