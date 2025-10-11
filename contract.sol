// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Motify
 * @notice A contract for managing stake-based challenges with a unified claim function.
 * @dev Implements a withdrawal pattern and a timeout fallback to protect user funds.
 */
contract Motify {
    uint256 public constant MIN_AMOUNT = 0.001 ether;
    uint256 public constant FEE_BASIS_POINTS = 50; // 0.5%
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;
    uint256 public constant DECLARATION_TIMEOUT = 7 days;

    address public owner;
    uint256 public nextChallengeId;
    uint256 public collectedFees;

    enum Status {
        PENDING,
        WINNER,
        LOSER
    }

    struct Participant {
        uint256 amount;
        Status status;
    }

    struct Challenge {
        address creator;
        address charity;
        uint256 endTime;
        bool resultsDeclared;
        mapping(address => Participant) participants;
    }

    mapping(uint256 => Challenge) public challenges;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    event ChallengeCreated(
        uint256 indexed challengeId,
        address indexed creator,
        address charity,
        uint256 endTime
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
        uint256 amount,
        string reason
    );
    event DonationSent(
        uint256 indexed challengeId,
        address indexed user,
        uint256 amountToCharity
    );

    constructor() {
        owner = msg.sender;
    }

    function createChallenge(
        address _charity,
        uint256 _endTime
    ) external returns (uint256) {
        require(_charity != address(0), "Invalid charity address");
        require(_endTime > block.timestamp, "End time must be in the future");

        uint256 challengeId = nextChallengeId++;
        Challenge storage ch = challenges[challengeId];
        ch.creator = msg.sender;
        ch.charity = _charity;
        ch.endTime = _endTime;

        emit ChallengeCreated(challengeId, msg.sender, _charity, ch.endTime);
        return challengeId;
    }

    function joinChallenge(uint256 _challengeId) external payable {
        Challenge storage ch = challenges[_challengeId];
        require(block.timestamp < ch.endTime, "Challenge ended");
        require(msg.value >= MIN_AMOUNT, "Below minimum");

        Participant storage p = ch.participants[msg.sender];
        require(p.amount == 0, "Already joined");

        p.amount = msg.value;
        p.status = Status.PENDING;

        emit JoinedChallenge(_challengeId, msg.sender, msg.value);
    }

    function declareResults(
        uint256 _challengeId,
        address[] calldata _winners,
        address[] calldata _losers
    ) external onlyOwner {
        Challenge storage ch = challenges[_challengeId];
        require(block.timestamp >= ch.endTime, "Challenge not ended yet");
        require(!ch.resultsDeclared, "Results already declared");
        require(
            block.timestamp <= ch.endTime + DECLARATION_TIMEOUT,
            "Declaration period has expired"
        );

        for (uint i = 0; i < _winners.length; i++) {
            Participant storage p = ch.participants[_winners[i]];
            if (p.amount > 0 && p.status == Status.PENDING) {
                p.status = Status.WINNER;
            }
        }

        for (uint i = 0; i < _losers.length; i++) {
            Participant storage p = ch.participants[_losers[i]];
            if (p.amount > 0 && p.status == Status.PENDING) {
                p.status = Status.LOSER;
            }
        }

        ch.resultsDeclared = true;
        emit ResultsDeclared(_challengeId);
    }

    function claim(uint256 _challengeId) external {
        Challenge storage ch = challenges[_challengeId];
        Participant storage p = ch.participants[msg.sender];
        require(p.amount > 0, "No funds to claim or already claimed");

        bool canClaimAsWinner = ch.resultsDeclared && p.status == Status.WINNER;
        bool canClaimAfterTimeout = !ch.resultsDeclared &&
            block.timestamp > ch.endTime + DECLARATION_TIMEOUT;

        require(
            canClaimAsWinner || canClaimAfterTimeout,
            "Claim conditions not met"
        );

        uint256 refundAmount = p.amount;
        p.amount = 0;

        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "Refund transfer failed");

        string memory reason = canClaimAsWinner
            ? "Winner claim"
            : "Timeout fallback";
        emit RefundClaimed(_challengeId, msg.sender, refundAmount, reason);
    }

    function processDonation(uint256 _challengeId, address _loser) external {
        Challenge storage ch = challenges[_challengeId];
        require(ch.resultsDeclared, "Results not declared yet");

        Participant storage p = ch.participants[_loser];
        require(p.status == Status.LOSER, "Not a loser or already processed");

        uint256 totalAmount = p.amount;
        p.amount = 0;

        uint256 fee = (totalAmount * FEE_BASIS_POINTS) / BASIS_POINTS_DIVISOR;
        uint256 donation = totalAmount - fee;

        collectedFees += fee;

        (bool success, ) = ch.charity.call{value: donation}("");
        require(success, "Charity transfer failed");

        emit DonationSent(_challengeId, _loser, donation);
    }

    function withdrawFees(address _to) external onlyOwner {
        require(_to != address(0), "Invalid address");
        uint256 amount = collectedFees;
        require(amount > 0, "No fees to withdraw");

        collectedFees = 0;

        (bool success, ) = _to.call{value: amount}("");
        require(success, "Withdraw failed");
    }

    function getParticipantInfo(
        uint256 _challengeId,
        address _user
    ) external view returns (uint256 amount, Status status) {
        Participant storage p = challenges[_challengeId].participants[_user];
        return (p.amount, p.status);
    }
}
