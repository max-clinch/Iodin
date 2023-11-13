// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./CombinedTribunalNFT.sol";

contract IodineToken is ERC20("Iodine Token", "IDN"), Ownable {
    using SafeMath for uint256;

    // Addresses allowed to mint new tokens (e.g., the platform creators)
    mapping(address => bool) public minters;

    // Vesting schedule for each beneficiary
    mapping(address => VestingSchedule) public vestingSchedules;

    // Addresses that reported ownership theft
    mapping(address => bool) public ownershipTheftReports;

    // Addresses that reported token theft
    mapping(address => bool) public tokenTheftReports;

    // Addresses that reported asset theft
    mapping(address => bool) public assetTheftReports;

    struct VestingSchedule {
        uint256 startTimestamp;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 totalAmount;
        uint256 releasedAmount;
    }

    // Events for tracking token minting, burning, and vesting
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event TokensVested(address indexed beneficiary, uint256 amount);
    event OwnershipTheftReported(address indexed reporter, address indexed thief);
    event TokenTheftReported(address indexed reporter, address indexed thief);
    event AssetTheftReported(address indexed reporter, address indexed thief);

    constructor() {
        // Mint an initial supply of tokens to the contract creator
        _mint(msg.sender, 1000000 * 10 ** uint256(decimals()));
        // Allow the contract creator to mint more tokens initially
        addMinter(msg.sender);
    }

    // Function to allow adding new minters (e.g., for platform upgrades)
    function addMinter(address _minter) public onlyOwner {
        minters[_minter] = true;
        emit MinterAdded(_minter);
    }

    // Function to remove a minter role
    function removeMinter(address _minter) public onlyOwner {
        minters[_minter] = false;
        emit MinterRemoved(_minter);
    }

    // Function to mint new tokens (only callable by authorized minters)
    function mint(address account, uint256 amount) public {
        require(minters[msg.sender], "Only authorized minters can mint tokens");
        _mint(account, amount);
        emit TokensMinted(account, amount);
    }

    // Function to burn tokens (only callable by the owner)
    function burn(uint256 amount) public onlyOwner {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    // Function to create a vesting schedule for a beneficiary
    function createVestingSchedule(
        address beneficiary,
        uint256 startTimestamp,
        uint256 cliffDuration,
        uint256 vestingDuration,
        uint256 totalAmount
    ) public onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting schedule already exists");

        require(totalAmount > 0, "Total amount must be greater than zero");
        require(startTimestamp >= block.timestamp, "Start timestamp must be in the future");
        require(cliffDuration <= vestingDuration, "Cliff duration must be less than or equal to vesting duration");

        VestingSchedule memory newSchedule = VestingSchedule({
            startTimestamp: startTimestamp,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            totalAmount: totalAmount,
            releasedAmount: 0
        });

        vestingSchedules[beneficiary] = newSchedule;
    }

    // Function to release vested tokens for a beneficiary
    function releaseVestedTokens(address beneficiary) public {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.totalAmount > 0, "Vesting schedule does not exist");
        require(block.timestamp >= schedule.startTimestamp, "Vesting has not started yet");

        uint256 vestedAmount = calculateVestedAmount(schedule);
        require(vestedAmount > schedule.releasedAmount, "No new tokens to release");

        uint256 unreleasedAmount = vestedAmount - schedule.releasedAmount;
        require(unreleasedAmount <= balanceOf(address(this)), "Not enough tokens in the contract");

        schedule.releasedAmount = vestedAmount;
        _transfer(address(this), beneficiary, unreleasedAmount);

        emit TokensVested(beneficiary, unreleasedAmount);
    }

    // Function to calculate the amount of tokens vested
    function calculateVestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        if (block.timestamp < schedule.startTimestamp.add(schedule.cliffDuration)) {
            return 0;
        } else if (block.timestamp >= schedule.startTimestamp.add(schedule.vestingDuration)) {
            return schedule.totalAmount;
        } else {
            uint256 elapsed = block.timestamp.sub(schedule.startTimestamp);
            uint256 vestingPeriod = schedule.vestingDuration;
            return schedule.totalAmount.mul(elapsed).div(vestingPeriod);
        }
    }

    // Function to transfer tokens, checking vesting status if applicable
    function transfer(address to, uint256 amount) public override returns (bool) {
        // Check if the sender has a vesting schedule
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        if (schedule.totalAmount > 0) {
            // Calculate the vested amount
            uint256 vestedAmount = calculateVestedAmount(schedule);
            // Ensure that the sender is not transferring more than the vested amount
            require(amount <= vestedAmount, "Transfer amount exceeds vested balance");
        }
        // Proceed with the standard ERC-20 transfer for users without vesting
        return super.transfer(to, amount);
    }

    // Function to report ownership theft
    function reportOwnershipTheft(address thief) public {
        require(thief != address(0), "Invalid thief address");
        require(msg.sender != thief, "You cannot report yourself");
        ownershipTheftReports[thief] = true;
        emit OwnershipTheftReported(msg.sender, thief);
    }

    // Function to report token theft
    function reportTokenTheft(address thief) public {
        require(thief != address(0), "Invalid thief address");
        require(msg.sender != thief, "You cannot report yourself");
        tokenTheftReports[thief] = true;
        emit TokenTheftReported(msg.sender, thief);
    }

    // Function to report asset theft
    function reportAssetTheft(address thief) public {
        require(thief != address(0), "Invalid thief address");
        require(msg.sender != thief, "You cannot report yourself");
        assetTheftReports[thief] = true;
        emit AssetTheftReported(msg.sender, thief);
    }
}