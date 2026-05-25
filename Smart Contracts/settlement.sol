// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IAuthentication {
    function isMember(address account) external view returns (bool);
} // checks membership

interface IEnergyListing {
    // mapping(uint256 => EnergyListing) public listings;
    // function getListing(uint256 listingId);
    // function listEnergy
    function ListingID() external view returns (uint256);
}


interface IEnergyTrading {

    struct Trade {
        uint256 listingId;
        address producer;
        address consumer;
        uint256 amountKwh;
        uint256 agreedWei;
        bool settled;
    }

    function getTrade(uint256 tradeId)
        external
        view
        returns (
            uint256,
            address,
            address,
            uint256,
            uint256,
            bool
        );

    function updateEnergyBalance(
        address user,
        uint256 amount,
        bool addEnergy
    ) external;

    function updateMoneyBalance(
        address user,
        uint256 amount,
        bool addMoney
    ) external;

    function markTradeSettled(uint256 tradeId)
        external;
}





contract Settlement {

    IAuthentication public authentication;
    IEnergyTrading public energyTrading;
    IEnergyListing public energy_listing;

    event TradeSettled(
        uint256 indexed ListingID,
        address indexed producer,
        address indexed consumer,
        uint256 amountKwh,
        uint256 agreedWei
    );

    constructor(address _authContract, address _energyTradingContract, address _listingAddress) {
        require(_listingAddress != address(0), "Invalid listing address");
        require(_authContract   != address(0), "Invalid auth address");

        authentication = IAuthentication(_authContract);
        energyTrading = IEnergyTrading(_energyTradingContract);
        energy_listing = IEnergyListing(_listingAddress);
    }

    modifier onlyMember() {
        require(
            authentication.isMember(msg.sender),
            "authentication: caller is not a verified member"
        );
        _;
    }

    function settleTrade(uint256 tradeId) external onlyMember {

        (
            uint256 ListingId,
            address producer,
            address consumer,
            uint256 amountKwh,
            uint256 agreedWei,
            bool settled
        ) = energyTrading.getTrade(tradeId);

        require(!settled, "Trade already settled");


        // Transfer energy
        energyTrading.updateEnergyBalance(
            producer,
            amountKwh,
            false
        );

        energyTrading.updateEnergyBalance(
            consumer,
            amountKwh,
            true
        );

        // Transfer money
        energyTrading.updateMoneyBalance(
            consumer,
            agreedWei,
            false
        );

        energyTrading.updateMoneyBalance(
            producer,
            agreedWei,
            true
        );

        // Mark settled
        energyTrading.markTradeSettled(tradeId);

        emit TradeSettled(
            tradeId,
            producer,
            consumer,
            amountKwh,
            agreedWei
        );
    }
}