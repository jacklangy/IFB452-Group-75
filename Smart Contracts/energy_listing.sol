// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;


contract EnergyTrading {
    address public owner;
    mapping(address => bool) public isRegulator;
    mapping(address => bool) public isMember;

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
        isMember[msg.sender] = true;
        // emit regulatorAdded(msg.sender, address(0));
    }
    function listEnergy(uint256 _amount, uint256 _price) external {
        require (_amount > 0, "amount must be greater than zero");
        require(isMember[msg.sender], "Must be a member to call this");

        listings[ListingId] = EnergyListing({
            seller: msg.sender,
            amountKwh: _amount,
            costPerKwh: _price,
            isActive: true
        });

        emit EnergyListed(ListingId, msg.sender, _amount, _price);
        ListingId++;
    }

    // function memberAction() external view returns (string memory) {
    //     require(isMember[msg.sender], "Must be a member to call this");
    //     return "Welcome to the inner circle.";
    // }

    function cancelListing(uint256 _id) external {
        require(listings[_id].seller == msg.sender, "Only seller can cancel");
        listings[_id].isActive = false;
    }
}
