// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAuthentication {
    function isMember(address account) external view returns (bool);
    function isRegulator(address account) external view returns (bool);
}

interface ITradeMatching {

    enum MatchStatus {
        Pending,
        Locked,
        Settled,
        Cancelled,
        Flagged
    }

    struct Match {
        uint256 bidId;
        uint256 listingId;
        address consumer;
        address producer;
        uint256 amountKwh;
        uint256 agreedWei;
        MatchStatus status;
        uint256 createdAt;
    }

    function getMatch(uint256 matchId)
        external
        view
        returns (Match memory);

    function confirmSettlement(uint256 matchId)
        external;
}

contract Settlement {

    // External contracts
    IAuthentication public authContract;
    ITradeMatching public tradeContract;

    address public owner;

    // Tracks completed energy trades
    struct EnergyAccount {
        uint256 kwhDelivered;
        uint256 kwhReceived;
        uint256 totalEarned;
        uint256 totalSpent;
    }

    mapping(address => EnergyAccount)
        public energyAccounts;

    enum DeliveryStatus {
        Pending,
        Confirmed,
        Disputed
    }

    struct SettlementRecord {
        uint256 matchId;
        address producer;
        address consumer;
        uint256 amountKwh;
        uint256 agreedWei;
        DeliveryStatus deliveryStatus;
        uint256 confirmedAt;
        address confirmedBy;
    }

    // Stores settlement data for each match
    mapping(uint256 => SettlementRecord)
        public settlements;

    uint256[] public settledMatchIds;

    event DeliveryConfirmed(
        uint256 indexed matchId,
        address indexed producer,
        address indexed consumer,
        uint256 amountKwh,
        uint256 weiReleased,
        address confirmedBy
    );

    event DeliveryDisputed(
        uint256 indexed matchId,
        address indexed raisedBy,
        string reason
    );

    event DisputeResolved(
        uint256 indexed matchId,
        address indexed resolvedBy,
        bool settlementProceeded
    );

    constructor(
        address _authAddress,
        address _tradeAddress
    ) {

        require(
            _authAddress != address(0),
            "Invalid auth address"
        );

        require(
            _tradeAddress != address(0),
            "Invalid trade address"
        );

        owner = msg.sender;

        authContract =
            IAuthentication(_authAddress);

        tradeContract =
            ITradeMatching(_tradeAddress);
    }

    // Confirms that energy delivery occurred
    // and releases payment to the producer
    function confirmDelivery(uint256 _matchId)
        external
    {

        require(
            authContract.isRegulator(msg.sender),
            "Caller is not a regulator"
        );

        ITradeMatching.Match memory m =
            tradeContract.getMatch(_matchId);

        require(
            m.status ==
            ITradeMatching.MatchStatus.Locked,
            "Match is not locked"
        );

        require(
            settlements[_matchId].confirmedAt == 0,
            "Settlement already confirmed"
        );

        settlements[_matchId] = SettlementRecord({
            matchId: _matchId,
            producer: m.producer,
            consumer: m.consumer,
            amountKwh: m.amountKwh,
            agreedWei: m.agreedWei,
            deliveryStatus:
                DeliveryStatus.Confirmed,
            confirmedAt: block.timestamp,
            confirmedBy: msg.sender
        });

        settledMatchIds.push(_matchId);

        // Update producer totals
        energyAccounts[m.producer]
            .kwhDelivered += m.amountKwh;

        energyAccounts[m.producer]
            .totalEarned += m.agreedWei;

        // Update consumer totals
        energyAccounts[m.consumer]
            .kwhReceived += m.amountKwh;

        energyAccounts[m.consumer]
            .totalSpent += m.agreedWei;

        // Release locked ETH
        tradeContract.confirmSettlement(
            _matchId
        );

        emit DeliveryConfirmed(
            _matchId,
            m.producer,
            m.consumer,
            m.amountKwh,
            m.agreedWei,
            msg.sender
        );
    }

    // Allows a trade participant to dispute
    // a locked match before settlement
    function raiseDispute(
        uint256 _matchId,
        string calldata _reason
    ) external {

        require(
            authContract.isMember(msg.sender),
            "Caller is not a member"
        );

        ITradeMatching.Match memory m =
            tradeContract.getMatch(_matchId);

        require(
            m.status ==
            ITradeMatching.MatchStatus.Locked,
            "Can only dispute locked matches"
        );

        require(
            msg.sender == m.consumer ||
            msg.sender == m.producer,
            "Not part of this trade"
        );

        require(
            settlements[_matchId].confirmedAt == 0,
            "Trade already settled"
        );

        settlements[_matchId]
            .deliveryStatus =
                DeliveryStatus.Disputed;

        emit DeliveryDisputed(
            _matchId,
            msg.sender,
            _reason
        );
    }

    // Regulator resolves disputed matches
    function resolveDispute(
        uint256 _matchId,
        bool _proceed
    ) external {

        require(
            authContract.isRegulator(msg.sender),
            "Caller is not a regulator"
        );

        require(
            settlements[_matchId]
                .deliveryStatus ==
            DeliveryStatus.Disputed,
            "No active dispute"
        );

        if (_proceed) {

            settlements[_matchId]
                .deliveryStatus =
                    DeliveryStatus.Confirmed;

            settlements[_matchId]
                .confirmedAt =
                    block.timestamp;

            settlements[_matchId]
                .confirmedBy =
                    msg.sender;

            ITradeMatching.Match memory m =
                tradeContract.getMatch(_matchId);

            settledMatchIds.push(_matchId);

            energyAccounts[m.producer]
                .kwhDelivered +=
                    m.amountKwh;

            energyAccounts[m.producer]
                .totalEarned +=
                    m.agreedWei;

            energyAccounts[m.consumer]
                .kwhReceived +=
                    m.amountKwh;

            energyAccounts[m.consumer]
                .totalSpent +=
                    m.agreedWei;

            tradeContract
                .confirmSettlement(_matchId);
        }

        emit DisputeResolved(
            _matchId,
            msg.sender,
            _proceed
        );
    }

    // Returns settlement details
    function getSettlement(uint256 _matchId)
        external
        view
        returns (SettlementRecord memory)
    {
        return settlements[_matchId];
    }

    // Returns all completed settlement IDs
    function getSettledMatchIds()
        external
        view
        returns (uint256[] memory)
    {
        return settledMatchIds;
    }

    // Returns trading statistics for an account
    function getEnergyAccount(address _account)
        external
        view
        returns (EnergyAccount memory)
    {
        return energyAccounts[_account];
    }

    // Total completed settlements
    function settlementCount()
        external
        view
        returns (uint256)
    {
        return settledMatchIds.length;
    }

    // Updates SC3 contract address
    function setTradeContract(
        address _newTradeAddress
    ) external {

        require(
            msg.sender == owner,
            "Caller is not owner"
        );

        require(
            _newTradeAddress != address(0),
            "Invalid address"
        );

        tradeContract =
            ITradeMatching(_newTradeAddress);
    }

    // Updates SC1 contract address
    function setAuthContract(
        address _newAuthAddress
    ) external {

        require(
            msg.sender == owner,
            "Caller is not owner"
        );

        require(
            _newAuthAddress != address(0),
            "Invalid address"
        );

        authContract =
            IAuthentication(_newAuthAddress);
    }
}
