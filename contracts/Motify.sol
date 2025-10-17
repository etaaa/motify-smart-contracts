// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Motify
 * @notice A contract for managing stake-based challenges with percentage-based refunds.
 * @dev Implements a withdrawal pattern for refunds. Donations and fees are processed in bulk by the owner.
 * @dev This design choice means small refund amounts may remain unclaimed in the contract if users
 * decide not to spend gas to retrieve them.
 */
contract Motify {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_AMOUNT = 1e6; // 1 USDC (6 decimals)
    uint256 public constant FEE_BASIS_POINTS = 1000; // 10%
    uint256 public constant BASIS_POINTS_DIVISOR = 10000; // 100% = 10000 basis points
    uint256 public constant DECLARATION_TIMEOUT = 7 days; // Time window to declare results

    IERC20 public immutable usdc;
    address public owner;
    uint256 public nextChallengeId;
    uint256 public collectedFees;

    struct Participant {
        // NOTE: The meaning of 'amount' changes.
        // Before results are declared, it's the initial stake.
        // After results are declared, it's the claimable refund amount.
        uint256 amount;
        uint256 refundPercentage; // 0-10000 (0% to 100% in basis points)
        bool resultDeclared;
    }

    struct Challenge {
        address creator;
        address recipient;
        uint256 endTime;
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
        bool isPrivate,
        bytes32 metadataHash
    );
    event JoinedChallenge(
        uint256 indexed challengeId,
        address indexed user,
        uint256 amount
    );
    event ResultsDeclared(
        uint256 indexed challengeId,
        uint256 totalDonationAmount,
        uint256 feesCollected
    );
    event RefundClaimed(
        uint256 indexed challengeId,
        address indexed user,
        uint256 refundAmount
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
        address[] calldata _whitelistedParticipants,
        bytes32 _metadataHash
    ) external returns (uint256) {
        require(_recipient != address(0), "Invalid recipient address");
        require(_endTime > block.timestamp, "End time must be in the future");

        uint256 challengeId = nextChallengeId++;
        Challenge storage ch = challenges[challengeId];
        ch.creator = msg.sender;
        ch.recipient = _recipient;
        ch.endTime = _endTime;
        ch.isPrivate = _isPrivate;

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
            _isPrivate,
            _metadataHash
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

        usdc.safeTransferFrom(msg.sender, address(this), _amount);

        p.amount = _amount;
        p.refundPercentage = 0;
        p.resultDeclared = false;

        emit JoinedChallenge(_challengeId, msg.sender, _amount);
    }

    /**
     * @notice Owner declares refund percentages and processes all donations/fees for a challenge at once.
     * @dev After this function runs, participants must call `claimRefund` to get their portion back.
     */
    function declareResults(
        uint256 _challengeId,
        address[] calldata _participants,
        uint256[] calldata _refundPercentages
    ) external onlyOwner {
        Challenge storage ch = challenges[_challengeId];
        require(block.timestamp >= ch.endTime, "Challenge not ended yet");
        require(
            block.timestamp <= ch.endTime + DECLARATION_TIMEOUT,
            "Declaration period has expired"
        );
        require(
            _participants.length == _refundPercentages.length,
            "Array length mismatch"
        );

        uint256 totalDonationForChallenge = 0;

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

            uint256 initialStake = p.amount;
            uint256 refundAmount = (initialStake * _refundPercentages[i]) /
                BASIS_POINTS_DIVISOR;
            uint256 donationAmount = initialStake - refundAmount;

            totalDonationForChallenge += donationAmount;

            // Overwrite the participant's amount with their claimable refund.
            p.amount = refundAmount;
            p.refundPercentage = _refundPercentages[i];
            p.resultDeclared = true;
        }

        // Process all donations and fees for this challenge in one transaction
        if (totalDonationForChallenge > 0) {
            uint256 fee = (totalDonationForChallenge * FEE_BASIS_POINTS) /
                BASIS_POINTS_DIVISOR;
            uint256 netDonation = totalDonationForChallenge - fee;

            collectedFees += fee;
            usdc.safeTransfer(ch.recipient, netDonation);

            emit ResultsDeclared(_challengeId, netDonation, fee);
        }
    }

    /**
     * @notice A participant claims their eligible refund after results have been declared.
     */
    function claimRefund(uint256 _challengeId) external {
        Challenge storage ch = challenges[_challengeId];
        Participant storage p = ch.participants[msg.sender];

        require(p.resultDeclared, "Results not yet declared");

        uint256 refundAmount = p.amount;
        require(refundAmount > 0, "No refund to claim or already claimed");

        // Checks-Effects-Interactions: Set amount to zero before transfer
        p.amount = 0;

        usdc.safeTransfer(msg.sender, refundAmount);

        emit RefundClaimed(_challengeId, msg.sender, refundAmount);
    }

    /**
     * @notice A participant claims a full refund if the owner failed to declare results in time.
     */
    function claimTimeoutRefund(uint256 _challengeId) external {
        Challenge storage ch = challenges[_challengeId];
        Participant storage p = ch.participants[msg.sender];

        require(!p.resultDeclared, "Results were already declared");
        require(
            block.timestamp > ch.endTime + DECLARATION_TIMEOUT,
            "Declaration period has not expired"
        );

        uint256 fullRefundAmount = p.amount;
        require(fullRefundAmount > 0, "No funds to claim or already claimed");

        // Checks-Effects-Interactions: Set amount to zero before transfer
        p.amount = 0;

        usdc.safeTransfer(msg.sender, fullRefundAmount);

        emit RefundClaimed(_challengeId, msg.sender, fullRefundAmount);
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
}
