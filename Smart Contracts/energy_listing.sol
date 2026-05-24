// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

interface IAuthentication {
    function isMember(address account) external view returns (bool);
    function isRegulator(address account) external view returns (bool);
}

contract EnergyTrading {
    address public owner;
    address public tradeMatchingContract;
    IAuthentication public authContract;


    struct EnergyListing {
        address seller;
        uint256 amountKwh;
        uint256 costPerKwh;
        bool isActive;
    }
    mapping(uint256 => EnergyListing) public listings;
    uint256 public ListingId;
    

    // Events
    event EnergyListed(uint256 indexed id, address indexed seller, uint256 amount, uint256 price);
    event ListingCancelled(uint256 indexed id, address indexed cancelledBy);
    event ListingLockedByMatch(uint256 indexed id, address indexed lockedBy);
    // event EnergyPurchased(uint256 indexed id, address indexed buyer, uint256 amount);

    constructor(address _authContractAddress) {
    owner = msg.sender;
    authContract = IAuthentication(_authContractAddress);
    }

    modifier onlyMember() {
        require(
            authContract.isMember(msg.sender),
            "Must be an approved member"
        );
        _;
    }

    modifier onlyRegulator() {
        require(
            authContract.isRegulator(msg.sender),
            "Must be a regulator"
        );
        _;
    }

    modifier onlyTradeMatching() {
        require(
            msg.sender == tradeMatchingContract,
            "Only TradeMatching contract can call this"
        );
        _;
    }
    function listEnergy(uint256 _amount, uint256 _price) external onlyMember {
        require (_amount > 0, "Amount must be greater than zero");
        require(_price > 0, "Price must be greater than zero");

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
        require(_id < ListingId, "Listing does not exist");
        require(listings[_id].seller == msg.sender, "Only seller can cancel");
        require(listings[_id].isActive, "Listing already inactive");

        listings[_id].isActive = false;

        emit ListingCancelled(_id, msg.sender);
    }

    function regulatorCancelListing(uint256 _id) external onlyRegulator {
        require(_id < ListingId, "Listing does not exist");
        require(listings[_id].isActive, "Listing already inactive");

        listings[_id].isActive = false;

        emit ListingCancelled(_id, msg.sender);
    }

    function lockListingForMatch(uint256 _id) external onlyTradeMatching {
        require(_id < ListingId, "Listing does not exist");
        require(listings[_id].isActive, "Listing is not active");

        listings[_id].isActive = false;

        emit ListingLockedByMatch(_id, msg.sender);
    }

    function setAuthContract(address _newAuthAddress) external {
        require(msg.sender == owner, "Only owner can update auth contract");

        authContract = IAuthentication(_newAuthAddress);
    }

    function setTradeMatchingContract(address _tradeMatchingAddress) external {
        require(msg.sender == owner, "Only owner can set TradeMatching address");
        require(_tradeMatchingAddress != address(0), "Invalid address");

        tradeMatchingContract = _tradeMatchingAddress;
    }

    
}
