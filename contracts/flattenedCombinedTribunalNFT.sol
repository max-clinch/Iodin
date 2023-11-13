// Sources flattened with hardhat v2.17.3 https://hardhat.org

// SPDX-License-Identifier: MIT

// File @openzeppelin/contracts/utils/Context.sol@v4.9.3

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


// File @openzeppelin/contracts/access/Ownable.sol@v4.9.3

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File contracts/CombinedTribunalNFT.sol

// Original license: SPDX_License_Identifier: MIT
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
