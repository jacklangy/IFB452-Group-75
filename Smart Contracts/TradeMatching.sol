// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;


// SC3 can query SC1 without importing the full contract
interface IAuthentication {
    function isRegulator(address account) external view returns (bool);
    function isMember(address account) external view returns (bool);
}

// SC3 can read and lock listings from SC2
interface IEnergyListing {
    function listings(uint256 id)
        external
        view
        returns (
            address seller,
            uint256 amountKwh,
            uint256 costPerKwh,
            bool isActive
        );

    function lockListingForMatch(uint256 id) external;
}
contract TradeMatching {

    // External contract references

    IAuthentication public authContract;
    IEnergyListing  public listingContract;

    // Data structures

    enum MatchStatus { Pending, Locked, Settled, Cancelled, Flagged }

    struct Bid {
        address  consumer;
        uint256  listingId;    
        uint256  offeredWei;    
        bool     isActive;
    }

    struct Match {
        uint256     bidId;
        uint256     listingId;
        address     consumer;
        address     producer;
        uint256     amountKwh;
        uint256     agreedWei;   
        MatchStatus status;
        uint256     createdAt;
    }

    // Store Bids and Matches

    mapping(uint256 => Bid)   public bids;
    mapping(uint256 => Match) public matches;

    uint256 public bidCount;
    uint256 public matchCount;

    // One open bid per consumer per listing
    mapping(address => mapping(uint256 => uint256)) public activeBidId;
    mapping(address => mapping(uint256 => bool))    public hasBid;

    // -- Events

    // Emitted when a consumer places a bid on a listing
    event BidPlaced(
        uint256 indexed bidId,
        uint256 indexed listingId,
        address indexed consumer,
        uint256 offeredWei
    );

    // Emitted when a bid is withdrawn before matching
    event BidWithdrawn(uint256 indexed bidId, address indexed consumer);

    // Emitted when a bid is successfully matched to a listing
    // SC4 (Settlement) listens for this event to initiate payment
    event MatchLocked(
        uint256 indexed matchId,
        uint256 indexed listingId,
        uint256 indexed bidId,
        address consumer,
        address producer,
        uint256 amountKwh,
        uint256 agreedWei
    );

    // Emitted when SC4 marks a match as settled (called back by SC4)
    event MatchSettled(uint256 indexed matchId);

    // Emitted when the regulator flags a suspicious match
    event MatchFlagged(uint256 indexed matchId, address indexed flaggedBy, string reason);

    // Emitted when a match is cancelled (by regulator or on revert)
    event MatchCancelled(uint256 indexed matchId, address indexed cancelledBy);

    // Modifiers

    modifier onlyMember() {
        require(
            authContract.isMember(msg.sender),
            "TradeMatching: caller is not a verified member"
        );
        _;
    }

    modifier onlyRegulator() {
        require(
            authContract.isRegulator(msg.sender),
            "TradeMatching: caller is not a regulator"
        );
        _;
    }

    // Constructor

    // @param _authAddress Deployed address of SC1 (Authentication)
    // @param _listingAddress Deployed address of SC2 (EnergyListing)
    constructor(address _authAddress, address _listingAddress) {
        require(_authAddress   != address(0), "Invalid auth address");
        require(_listingAddress != address(0), "Invalid listing address");

        authContract    = IAuthentication(_authAddress);
        listingContract = IEnergyListing(_listingAddress);
    }

    // Consumer actions


    // @param _listingId  The listing the consumer wants to purchase
    // Place a bid on a specific energy listing
    function placeBid(uint256 _listingId) external payable onlyMember {
        require(msg.value > 0, "Bid must include ETH");

        // Pull listing data from SC2 and validate it is still available
        (
            address seller,
            uint256 amountKwh,
            uint256 costPerKwh,
            bool    isActive
        ) = listingContract.listings(_listingId);

        require(isActive,                   "Listing is not active");
        require(seller != address(0),        "Listing does not exist");
        require(msg.sender != seller,        "Seller cannot bid on own listing");
        require(!hasBid[msg.sender][_listingId], "Bid already placed on this listing");

        // Validate the consumer has offered enough to cover the listing price
        uint256 totalCost = costPerKwh * amountKwh;
        require(msg.value >= totalCost, "Insufficient ETH for listing price");

        uint256 bidId = bidCount++;

        bids[bidId] = Bid({
            consumer:    msg.sender,
            listingId:   _listingId,
            offeredWei:  msg.value,
            isActive:    true
        });

        activeBidId[msg.sender][_listingId] = bidId;
        hasBid[msg.sender][_listingId]      = true;

        emit BidPlaced(bidId, _listingId, msg.sender, msg.value);
    }

    // @param _bidId  The bid to withdraw
    // Withdraw an unmatched bid and reclaim ETH
    function withdrawBid(uint256 _bidId) external {
        Bid storage bid = bids[_bidId];

        require(bid.consumer == msg.sender, "Not your bid");
        require(bid.isActive,               "Bid is no longer active");

        bid.isActive = false;
        hasBid[msg.sender][bid.listingId] = false;

        uint256 refund = bid.offeredWei;
        bid.offeredWei = 0;

        // Refund ETH to consumer
        (bool sent, ) = payable(msg.sender).call{value: refund}("");
        require(sent, "ETH refund failed");

        emit BidWithdrawn(_bidId, msg.sender);
    }

    // Matching logic

    // @param _bidId  The bid to lock
    // Lock a bid-to-listing match and notify SC4
    function lockMatch(uint256 _bidId) external {
        Bid storage bid = bids[_bidId];
        require(bid.isActive, "Bid is not active");

        (
            address seller,
            uint256 amountKwh,
            uint256 costPerKwh,
            bool    isActive
        ) = listingContract.listings(bid.listingId);

        require(isActive,  "Listing is no longer active");

        // Only the producer who owns the listing (or the regulator) may lock
        require(
            msg.sender == seller || authContract.isRegulator(msg.sender),
            "Only the producer or regulator can lock a match"
        );

        // Confirm bid still covers the listing price (guards against price edits)
        uint256 totalCost = costPerKwh * amountKwh;
        require(bid.offeredWei >= totalCost, "Bid no longer covers listing price");

        // Deactivate both the bid and the SC2 listing
        bid.isActive = false;
        listingContract.lockListingForMatch(bid.listingId);

        uint256 matchId = matchCount++;

        matches[matchId] = Match({
            bidId:      _bidId,
            listingId:  bid.listingId,
            consumer:   bid.consumer,
            producer:   seller,
            amountKwh:  amountKwh,
            agreedWei:  bid.offeredWei,
            status:     MatchStatus.Locked,
            createdAt:  block.timestamp
        });

        emit MatchLocked(
            matchId,
            bid.listingId,
            _bidId,
            bid.consumer,
            seller,
            amountKwh,
            bid.offeredWei
        );
    }

    // Settlement callback (called by SC4)

    // SC4 calls this after verifying oracle delivery to release ETH to the producer and mark the match settled.
    // @param _matchId  The match that has been confirmed delivered
    function confirmSettlement(uint256 _matchId) external {
        Match storage m = matches[_matchId];

        require(m.status == MatchStatus.Locked, "Match is not in Locked state");

        // In production, restrict this to the deployed SC4 address.
        // For the prototype, any regulator-approved address may call this.
        require(
            authContract.isRegulator(msg.sender),
            "Only regulator/SC4 can confirm settlement"
        );

        m.status = MatchStatus.Settled;

        uint256 payment = m.agreedWei;
        m.agreedWei = 0;

        (bool sent, ) = payable(m.producer).call{value: payment}("");
        require(sent, "ETH transfer to producer failed");

        emit MatchSettled(_matchId);
    }

    // Regulator actions

    // Flag a suspicious or non-compliant match for manual review
    // @param _matchId  The match to flag
    // @param _reason   Short human-readable reason (stored off-chain via event)
    function flagMatch(uint256 _matchId, string calldata _reason) external onlyRegulator {
        Match storage m = matches[_matchId];
        require(
            m.status == MatchStatus.Locked,
            "Only Locked matches can be flagged"
        );

        m.status = MatchStatus.Flagged;
        emit MatchFlagged(_matchId, msg.sender, _reason);
    }

    // Cancel a flagged match and refund the consumer
    // @param _matchId  The flagged match to cancel
    function cancelFlaggedMatch(uint256 _matchId) external onlyRegulator {
        Match storage m = matches[_matchId];
        require(m.status == MatchStatus.Flagged, "Match is not flagged");

        m.status = MatchStatus.Cancelled;

        uint256 refund = m.agreedWei;
        m.agreedWei = 0;

        (bool sent, ) = payable(m.consumer).call{value: refund}("");
        require(sent, "ETH refund to consumer failed");

        emit MatchCancelled(_matchId, msg.sender);
    }

    // View helpers

    // Returns the full Match struct for a given matchId
    function getMatch(uint256 _matchId)
        external
        view
        returns (Match memory)
    {
        return matches[_matchId];
    }

    // Returns the full Bid struct for a given bidId
    function getBid(uint256 _bidId)
        external
        view
        returns (Bid memory)
    {
        return bids[_bidId];
    }

    // Convenience: returns ETH balance held in this contract
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // Fallback

    receive() external payable {}
}
