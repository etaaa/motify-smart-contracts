// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Motify
 * @notice A contract for managing stake-based challenges with percentage-based refunds.
 * @dev Implements a withdrawal pattern and a timeout fallback to protect user funds.
 */
contract Motify {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_AMOUNT = 1e6; // 1 USDC (6 decimals)
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BASIS_POINTS_DIVISOR = 10000; // 100% = 10000 basis points
    uint256 public constant DECLARATION_TIMEOUT = 7 days; // Time window to declare results

    IERC20 public immutable usdc;
    address public owner;
    uint256 public nextChallengeId;
    uint256 public collectedFees;

    struct Participant {
        uint256 amount;
        uint256 refundPercentage; // 0-10000 (0% to 100% in basis points)
        bool resultDeclared;
    }

    struct Challenge {
        address creator;
        address recipient;
        uint256 endTime;
        bool resultsDeclared;
        bool isPrivate; // If true, only whitelisted addresses can join
        mapping(address => Participant) participants;
        mapping(address => bool) whitelist;
    }

    // Store all challenges by ID
    mapping(uint256 => Challenge) public challenges;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    event ChallengeCreated(
        uint256 indexed challengeId,
        address indexed creator,
        address recipient,
        uint256 endTime,
        bool isPrivate
    );
    event JoinedChallenge(
        uint256 indexed challengeId,
        address indexed user,
        uint256 amount
    );
    event ResultsDeclared(uint256 indexed challengeId);
    event RefundClaimed(
        uint256 indexed challengeId,
        address indexed user,
        uint256 refundAmount,
        uint256 refundPercentage
    );
    event DonationSent(
        uint256 indexed challengeId,
        address indexed user,
        uint256 amountToRecipient
    );
    event ParticipantsWhitelisted(
        uint256 indexed challengeId,
        address[] participants
    );

    constructor(address _usdcAddress) {
        owner = msg.sender;
        usdc = IERC20(_usdcAddress);
    }

    /**
     * @notice Create a new challenge
     */
    function createChallenge(
        address _recipient,
        uint256 _endTime,
        bool _isPrivate,
        address[] calldata _whitelistedParticipants
    ) external returns (uint256) {
        require(_recipient != address(0), "Invalid recipient address");
        require(_endTime > block.timestamp, "End time must be in the future");

        uint256 challengeId = nextChallengeId++;
        Challenge storage ch = challenges[challengeId];
        ch.creator = msg.sender;
        ch.recipient = _recipient;
        ch.endTime = _endTime;
        ch.isPrivate = _isPrivate;

        // If private, whitelist specific addresses
        if (_isPrivate) {
            require(
                _whitelistedParticipants.length > 0,
                "Private challenge needs participants"
            );
            for (uint i = 0; i < _whitelistedParticipants.length; i++) {
                ch.whitelist[_whitelistedParticipants[i]] = true;
            }
            emit ParticipantsWhitelisted(challengeId, _whitelistedParticipants);
        }

        emit ChallengeCreated(
            challengeId,
            msg.sender,
            _recipient,
            ch.endTime,
            _isPrivate
        );
        return challengeId;
    }

    /**
     * @notice Join an existing challenge by staking USDC
     */
    function joinChallenge(uint256 _challengeId, uint256 _amount) external {
        Challenge storage ch = challenges[_challengeId];
        require(block.timestamp < ch.endTime, "Challenge ended");
        require(_amount >= MIN_AMOUNT, "Below minimum");

        if (ch.isPrivate) {
            require(
                ch.whitelist[msg.sender],
                "Not whitelisted for this challenge"
            );
        }

        Participant storage p = ch.participants[msg.sender];
        require(p.amount == 0, "Already joined");

        // Transfer USDC to contract
        usdc.safeTransferFrom(msg.sender, address(this), _amount);

        // Save participant info
        p.amount = _amount;
        p.refundPercentage = 0;
        p.resultDeclared = false;

        emit JoinedChallenge(_challengeId, msg.sender, _amount);
    }

    /**
     * @notice Owner declares refund percentages after challenge ends
     */
    function declareResults(
        uint256 _challengeId,
        address[] calldata _participants,
        uint256[] calldata _refundPercentages
    ) external onlyOwner {
        Challenge storage ch = challenges[_challengeId];
        require(block.timestamp >= ch.endTime, "Challenge not ended yet");
        require(!ch.resultsDeclared, "Results already declared");
        require(
            block.timestamp <= ch.endTime + DECLARATION_TIMEOUT,
            "Declaration period has expired"
        );
        require(
            _participants.length == _refundPercentages.length,
            "Array length mismatch"
        );

        // Assign refund % for each participant
        for (uint i = 0; i < _participants.length; i++) {
            require(
                _refundPercentages[i] <= BASIS_POINTS_DIVISOR,
                "Invalid refund percentage"
            );

            Participant storage p = ch.participants[_participants[i]];
            require(p.amount > 0, "Participant not found");
            require(
                !p.resultDeclared,
                "Result already declared for participant"
            );

            p.refundPercentage = _refundPercentages[i];
            p.resultDeclared = true;
        }

        ch.resultsDeclared = true;
        emit ResultsDeclared(_challengeId);
    }

    /**
     * @notice Participant claims refund or donation is sent after results
     */
    function claim(uint256 _challengeId) external {
        Challenge storage ch = challenges[_challengeId];
        Participant storage p = ch.participants[msg.sender];
        require(p.amount > 0, "No funds to claim or already claimed");

        bool canClaimWithResult = ch.resultsDeclared && p.resultDeclared;
        bool canClaimAfterTimeout = !ch.resultsDeclared &&
            block.timestamp > ch.endTime + DECLARATION_TIMEOUT;

        require(
            canClaimWithResult || canClaimAfterTimeout,
            "Claim conditions not met"
        );

        uint256 totalAmount = p.amount;
        p.amount = 0;

        // Case 1: Owner didn’t declare results in time — full refund
        if (canClaimAfterTimeout) {
            usdc.safeTransfer(msg.sender, totalAmount);
            emit RefundClaimed(
                _challengeId,
                msg.sender,
                totalAmount,
                BASIS_POINTS_DIVISOR
            );
            return;
        }

        // Case 2: Refund and donation split
        uint256 refundAmount = (totalAmount * p.refundPercentage) /
            BASIS_POINTS_DIVISOR;
        uint256 donationAmount = totalAmount - refundAmount;

        // Send refund to participant
        if (refundAmount > 0) {
            usdc.safeTransfer(msg.sender, refundAmount);
            emit RefundClaimed(
                _challengeId,
                msg.sender,
                refundAmount,
                p.refundPercentage
            );
        }

        // Send donation (minus fee) to recipient
        if (donationAmount > 0) {
            uint256 fee = (donationAmount * FEE_BASIS_POINTS) /
                BASIS_POINTS_DIVISOR;
            uint256 netDonation = donationAmount - fee;

            collectedFees += fee;
            usdc.safeTransfer(ch.recipient, netDonation);

            emit DonationSent(_challengeId, msg.sender, netDonation);
        }
    }

    /**
     * @notice Owner withdraws collected platform fees
     */
    function withdrawFees(address _to) external onlyOwner {
        require(_to != address(0), "Invalid address");
        uint256 amount = collectedFees;
        require(amount > 0, "No fees to withdraw");

        collectedFees = 0;

        usdc.safeTransfer(_to, amount);
    }

    /**
     * @notice View info about a participant in a challenge
     */
    function getParticipantInfo(
        uint256 _challengeId,
        address _user
    )
        external
        view
        returns (uint256 amount, uint256 refundPercentage, bool resultDeclared)
    {
        Participant storage p = challenges[_challengeId].participants[_user];
        return (p.amount, p.refundPercentage, p.resultDeclared);
    }

    /**
     * @notice Check if a user is whitelisted for a private challenge
     */
    function isWhitelisted(
        uint256 _challengeId,
        address _user
    ) external view returns (bool) {
        return challenges[_challengeId].whitelist[_user];
    }

    /**
     * @notice View main info about a challenge
     */
    function getChallengeInfo(
        uint256 _challengeId
    )
        external
        view
        returns (
            address creator,
            address recipient,
            uint256 endTime,
            bool resultsDeclared,
            bool isPrivate
        )
    {
        Challenge storage ch = challenges[_challengeId];
        return (
            ch.creator,
            ch.recipient,
            ch.endTime,
            ch.resultsDeclared,
            ch.isPrivate
        );
    }
}
