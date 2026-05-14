// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleEnergyLedger {

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

    // Register a participant
    function registerParticipant(address participant) external {
        participants[participant].registered = true;
    }

    // Log a trade
    function logTrade(address buyer, uint256 amount, uint256 pricePerKWh) external {
        require(participants[msg.sender].registered, "Seller not registered");
        require(participants[buyer].registered, "Buyer not registered");

        // Record trade
        trades.push(Trade({
            seller: msg.sender,
            buyer: buyer,
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