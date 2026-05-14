// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;


contract EnergyTrading {
    address public owner;

    struct EnergyListing {
        address seller;
        uint256 amountKwh;
        uint256 costPerKwh;
        bool isActive;
    }
    mapping(uint256 => EnergyListing) public listings;
    uint256 public ListingId;
    
    event EnergyListed(uint256 indexed id, address indexed seller, uint256 amount, uint256 price);
    // event EnergyPurchased(uint256 indexed id, address indexed buyer, uint256 amount);

    constructor() {
        owner = msg.sender;
    }
    function listEnergy(uint256 _amount, uint256 _price) external {
        require (_amount > 0, "amount must be greater than zero");

        listings[ListingId] = EnergyListing({
            seller: msg.sender,
            amountKwh: _amount,
            costPerKwh: _price,
            isActive: true
        });

        emit EnergyListed(ListingId, msg.sender, _amount, _price);
        ListingId++;
    }

    // function buyEnergy(uint256 _id) external payable {
    //     EnergyListing storage listing = listings[_id];

    //     require(listing.isActive, "Listing is not available");
    //     require(msg.value >= listing.costPerKwh, "insufficient funds");
    //     require(msg.sender != listing.seller, "Cannot buy your own listing");

    //     listing.isActive = false;

    //     emit EnergyPurchased(_id, msg.sender, listing.amountKwh);
    // }

    function cancelListing(uint256 _id) external {
        require(listings[_id].seller == msg.sender, "Only seller can cancel");
        listings[_id].isActive = false;
    }
}
