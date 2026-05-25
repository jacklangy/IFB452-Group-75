// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAuthentication {
    function isMember(address account) external view returns (bool);
} // checks membership

contract SimpleEnergyLedger {

    IAuthentication public authContract;
    struct Participant {
        bool registered;
        uint256 energyBalance; // in kWh
        uint256 creditBalance; // in units of currency
    }

    mapping(address => Participant) public participants;

    struct Trade {
        address seller;
        address buyer;
        uint256 amount; // kWh
        uint256 pricePerKWh;
    }

    Trade[] public trades;

    constructor(address _authContractAddress) {
        authContract = IAuthentication(_authContractAddress);
    }

    // Register a participant
    // function registerParticipant(address participant) external {
    //     participants[participant].registered = true;
    // }

    // Log a trade
    function logTrade(address account, uint256 amount, uint256 pricePerKWh) external {
        require(IAuthentication.isMember(msg.sender), "user not registered");
        // require (authContract)
        // require(participants[buyer].registered, "Buyer not registered");

        // Record trade
        trades.push(Trade({
            seller: msg.sender,
            // buyer: isMember,
            amount: amount,
            pricePerKWh: pricePerKWh
        }));

        // Update balances
        participants[msg.sender].energyBalance -= amount;
        participants[buyer].energyBalance += amount;
        participants[buyer].creditBalance += amount * pricePerKWh;
    }

    // Get total number of trades
    function getTradeCount() external view returns (uint256) {
        return trades.length;
    }
}