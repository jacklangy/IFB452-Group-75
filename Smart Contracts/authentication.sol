// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


contract authentication {
    // Mappings to track roles
    mapping(address => bool) public isRegulator;
    mapping(address => bool) public isMember;

    // Tracks addresses that have applied but not yet been approved
    mapping(address => bool) public hasPendingApplication;
    address[] public applicantList;

    // Events for transparency
    event regulatorAdded(address indexed account, address indexed addedBy);
    event regulatorRemoved(address indexed account, address indexed removedBy);
    event MemberPromoted(address indexed account, address indexed promotedBy);
    event MemberDemoted(address indexed account, address indexed demotedBy);
    event ApplicationSubmitted(address indexed applicant);
    event ApplicationRejected(address indexed applicant, address indexed rejectedBy);


    modifier onlyRegulator() {
        require(isRegulator[msg.sender], "Access Denied: You are not an admin");
        _;
    }


    constructor() {
        isRegulator[msg.sender] = true;
        emit regulatorAdded(msg.sender, address(0));
    }

    // Anyone can call this to submit a membership application
    function applyForMembership() external {
        require(!isMember[msg.sender], "Already a member");
        require(!isRegulator[msg.sender], "Regulators cannot apply");
        require(!hasPendingApplication[msg.sender], "Application already pending");

        hasPendingApplication[msg.sender] = true;
        applicantList.push(msg.sender);

        emit ApplicationSubmitted(msg.sender);
    }

    // Returns all pending applicant addresses
    function getApplicants() external view returns (address[] memory) {
        return applicantList;
    }

    // Regulator: Approve / Reject

    function approveApplicant(address _applicant) external onlyRegulator {
        require(hasPendingApplication[_applicant], "No pending application");

        hasPendingApplication[_applicant] = false;
        _removeFromApplicantList(_applicant);

        isMember[_applicant] = true;
        emit MemberPromoted(_applicant, msg.sender);
    }

    function rejectApplicant(address _applicant) external onlyRegulator {
        require(hasPendingApplication[_applicant], "No pending application");

        hasPendingApplication[_applicant] = false;
        _removeFromApplicantList(_applicant);

        emit ApplicationRejected(_applicant, msg.sender);
    }



    // Admin Management Functions


    function addRegulator(address _newRegulator) external onlyRegulator {
        require(_newRegulator != address(0), "Cannot add zero address");
        require(!isRegulator[_newRegulator], "Address is already an admin");

        isRegulator[_newRegulator] = true;
        emit regulatorAdded(_newRegulator, msg.sender);
    }


    function removeRegulator(address _regulatorToRemove) external onlyRegulator {
        require(isRegulator[_regulatorToRemove], "Address is not an admin");
        require(msg.sender != _regulatorToRemove, "You cannot remove yourself");

        isRegulator[_regulatorToRemove] = false;
        emit regulatorRemoved(_regulatorToRemove, msg.sender);
    }

    // Membership Management Functions


    function promoteToMember(address _account) external onlyRegulator {
        require(!isMember[_account], "Already a member");
        
        isMember[_account] = true;
        emit MemberPromoted(_account, msg.sender);
    }


    function demoteFromMember(address _account) external onlyRegulator {
        require(isMember[_account], "Not a member");
        
        isMember[_account] = false;
        emit MemberDemoted(_account, msg.sender);
    }


    function memberAction() external view returns (string memory) {
        require(isMember[msg.sender], "Must be a member to call this");
        return "Welcome to the inner circle.";
    }

    // Internal Helper

    function _removeFromApplicantList(address _applicant) internal {
        for (uint i = 0; i < applicantList.length; i++) {
            if (applicantList[i] == _applicant) {
                applicantList[i] = applicantList[applicantList.length - 1];
                applicantList.pop();
                break;
            }
        }
    }
}
