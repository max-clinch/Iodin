// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CombinedTribunal is Ownable {
    struct TheftCase {
        address thief;
        address victim;
        uint256 stolenAmount;
        bool resolved;
        bool fundsInEscrow;
        address fundsBeneficiary;
        bytes32 txHash;
    }

    struct Escrow {
        address beneficiary;
        uint256 amount;
    }

    struct Proposal {
        uint256 tokenId;
        string description;
        address creator;
        uint256 votes;
        bool isExecuted;
        bool isOpen;
    }

    mapping(uint256 => TheftCase) public theftCases;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => Escrow) public escrows;

    uint256 public caseCounter;
    uint256 public proposalCounter;
    uint256 public escrowCounter;

    mapping(address => bool) public validAddresses;

    modifier onlyValidAddress() {
        require(validAddresses[msg.sender], "Caller is not a valid address");
        _;
    }

    constructor() {
        caseCounter = 1;
        proposalCounter = 1;
        escrowCounter = 1;
    }

    function addValidAddress(address _address) external onlyOwner {
        validAddresses[_address] = true;
    }

    function removeValidAddress(address _address) external onlyOwner {
        validAddresses[_address] = false;
    }

    function createTheftCase(
        address _thief,
        address _victim,
        uint256 _stolenAmount,
        bytes32 _txHash
    ) external payable {
        require(_victim != address(0), "Invalid victim address");
        require(_thief != address(0), "Invalid thief address");
        require(_stolenAmount > 0, "Stolen amount must be greater than 0");
        require(msg.value >= _stolenAmount, "Sent Ether must be equal to or greater than the stolen amount");

        escrows[escrowCounter] = Escrow({
            beneficiary: _victim,
            amount: _stolenAmount
        });

        theftCases[caseCounter] = TheftCase({
            thief: _thief,
            victim: _victim,
            stolenAmount: _stolenAmount,
            resolved: false,
            fundsInEscrow: true,
            fundsBeneficiary: address(0),
            txHash: _txHash
        });

        caseCounter++;
        escrowCounter++;

        address escrowAddress = address(this);
        payable(escrowAddress).transfer(_stolenAmount);
    }

    function releaseFundsFromEscrow(uint256 _caseId) external onlyValidAddress {
        TheftCase storage theftCase = theftCases[_caseId];
        require(theftCase.fundsInEscrow, "Funds are not in escrow for this case");
        require(!theftCase.resolved, "Theft case is already resolved");

        Escrow storage escrow = escrows[_caseId];
        address beneficiary = escrow.beneficiary;
        uint256 amount = escrow.amount;

        theftCase.resolved = true;
        theftCase.fundsInEscrow = false;

        payable(beneficiary).transfer(amount);
    }

    function resolveTheftCase(uint256 _caseId) external onlyValidAddress {
        TheftCase storage theftCase = theftCases[_caseId];
        require(!theftCase.resolved, "Theft case is already resolved");

        theftCase.resolved = true;
    }

    function unlockFunds(uint256 _caseId, address _beneficiary) external onlyValidAddress {
        TheftCase storage theftCase = theftCases[_caseId];
        require(!theftCase.resolved, "Theft case is already resolved");
        require(theftCase.fundsInEscrow, "Funds are not in escrow for this case");

        theftCase.fundsBeneficiary = _beneficiary;
        theftCase.fundsInEscrow = false;
    }

    function reportOwnershipTheft(uint256 _caseId, address _thief) view  external {
        TheftCase storage theftCase = theftCases[_caseId];
        require(owner() == msg.sender, "Only the owner can report ownership theft");
        require(!theftCase.resolved, "Theft case is already resolved");
    }

    function reportTheftCase(
        address _thief,
        address _victim,
        uint256 _stolenAmount,
        bytes32 _txHash
    ) external {
        require(_stolenAmount > 0, "Stolen amount must be greater than 0");

        escrows[escrowCounter] = Escrow({
            beneficiary: _victim,
            amount: _stolenAmount
        });

        theftCases[caseCounter] = TheftCase({
            thief: _thief,
            victim: _victim,
            stolenAmount: _stolenAmount,
            resolved: false,
            fundsInEscrow: true,
            fundsBeneficiary: address(0),
            txHash: _txHash
        });

        caseCounter++;
        escrowCounter++;
    }

    function reportAssetTheft(uint256 _caseId, address _thief) view  external {
        TheftCase storage theftCase = theftCases[_caseId];
        require(!theftCase.resolved, "Theft case is already resolved");
    }

    function lockFunds(uint256 _caseId) external onlyValidAddress {
        TheftCase storage theftCase = theftCases[_caseId];
        require(!theftCase.resolved, "Theft case is already resolved");
        require(!theftCase.fundsInEscrow, "Funds are already in escrow");

        theftCase.fundsInEscrow = true;
    }

    event FundsTransferredToEscrow(
        uint256 caseId,
        address beneficiary,
        uint256 amount,
        bytes32 txHash
    );

    event OwnershipTheftReported(uint256 caseId, address thief);
    event TokenTheftReported(uint256 caseId, address thief);
    event AssetTheftReported(uint256 caseId, address thief);
    event FundsUnlocked(uint256 caseId, address beneficiary);
    event ProposalCreated(
        uint256 proposalId,
        uint256 tokenId,
        string description
    );
    event VotedOnProposal(uint256 proposalId, address voter, uint256 votes);

    function createProposal(uint256 _tokenId, string memory _description)
        external
        onlyValidAddress
    {
        require(owner() == msg.sender, "Only the owner can create a proposal");
        Proposal storage newProposal = proposals[proposalCounter];
        newProposal.tokenId = _tokenId;
        newProposal.description = _description;
        newProposal.creator = msg.sender;
        newProposal.votes = 0;
        newProposal.isExecuted = false;
        newProposal.isOpen = true;
        proposalCounter++;

        emit ProposalCreated(proposalCounter - 1, _tokenId, _description);
    }

    function voteOnProposal(uint256 _proposalId) external onlyValidAddress {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.isOpen, "Proposal is not open for voting");
        proposal.votes++;
        emit VotedOnProposal(_proposalId, msg.sender, proposal.votes);
    }

    function closeAndExecuteProposal(uint256 _proposalId) external onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.isOpen, "Proposal is not open");
        proposal.isOpen = false;
        if (proposal.votes > 0) {
            proposal.isExecuted = true;
        }
    }
}
