// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IMotifyToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Motify
 * @notice A contract for managing stake-based challenges with percentage-based refunds.
 * @dev Implements a withdrawal pattern for refunds. Donations and fees are processed in bulk by the owner.
 * @dev Results are declared in batches to support challenges with a large number of participants.
 * @dev Integrated with MotifyToken for rewarding winners with tokens backed by 50% of fees.
 */
contract Motify {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_AMOUNT = 1e6; // 1 USDC (6 decimals)
    uint256 public constant FEE_BASIS_POINTS = 1000; // 10%
    uint256 public constant BASIS_POINTS_DIVISOR = 10000; // 100% = 10000 basis points
    uint256 public constant DECLARATION_TIMEOUT = 7 days; // Time window to declare results
    uint256 public constant TOKENS_PER_USDC = 10000; // 1 USDC = 10000 tokens
    uint256 public constant MAX_DESCRIPTION_LENGTH = 160; // Maximum characters for challenge description

    IERC20 public immutable usdc;
    IMotifyToken public motifyToken;
    address public owner;
    uint256 public nextChallengeId;
    uint256 public collectedFees;

    struct Participant {
        uint256 initialAmount; // Initial stake amount
        uint256 amount; // After results: claimable refund amount
        uint256 refundPercentage; // 0-10000 (0% to 100% in basis points)
        bool resultDeclared;
    }

    struct Challenge {
        address recipient;
        uint256 startTime;
        uint256 endTime;
        bool isPrivate;
        string name;
        string apiType;
        string goalType;
        uint256 goalAmount;
        string description;
        mapping(address => Participant) participants;
        address[] participantAddresses; // Track all participant addresses
        mapping(address => bool) whitelist;
        uint256 totalDonationAmount;
        uint256 totalWinnerInitialStake;
        uint256 tokenPot;
        uint256 declaredParticipants;
        bool resultsFinalized; // Locks the challenge after processing donations.
    }

    mapping(uint256 => Challenge) public challenges;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(address _usdcAddress) {
        require(_usdcAddress != address(0), "USDC address cannot be zero");
        owner = msg.sender;
        usdc = IERC20(_usdcAddress);
    }

    /**
     * @notice Set the MotifyToken address (one-time only).
     */
    function setTokenAddress(address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid token address");
        require(address(motifyToken) == address(0), "Already set");
        motifyToken = IMotifyToken(_tokenAddress);
    }

    /**
     * @notice Create a new challenge
     */
    function createChallenge(
        address _recipient,
        uint256 _startTime,
        uint256 _endTime,
        bool _isPrivate,
        string calldata _name,
        string calldata _apiType,
        string calldata _goalType,
        uint256 _goalAmount,
        string calldata _description,
        address[] calldata _whitelistedParticipants
    ) external returns (uint256) {
        require(_recipient != address(0), "Invalid recipient address");
        require(
            _startTime > block.timestamp,
            "Start time must be in the future"
        );
        require(_endTime > _startTime, "End time must be after start time");
        require(
            bytes(_description).length <= MAX_DESCRIPTION_LENGTH,
            "Description too long"
        );

        uint256 challengeId = nextChallengeId++;
        Challenge storage ch = challenges[challengeId];
        ch.recipient = _recipient;
        ch.startTime = _startTime;
        ch.endTime = _endTime;
        ch.isPrivate = _isPrivate;
        ch.name = _name;
        ch.apiType = _apiType;
        ch.goalType = _goalType;
        ch.goalAmount = _goalAmount;
        ch.description = _description;

        if (_isPrivate) {
            require(
                _whitelistedParticipants.length > 0,
                "Private challenge needs participants"
            );
            for (uint i = 0; i < _whitelistedParticipants.length; i++) {
                ch.whitelist[_whitelistedParticipants[i]] = true;
            }
        }

        return challengeId;
    }

    /**
     * @notice Join a challenge
     * @dev User must have already called usdc.approve(address(this), stakeAmount)
     */
    function joinChallenge(
        uint256 _challengeId,
        uint256 _stakeAmount
    ) external {
        Challenge storage ch = challenges[_challengeId];
        require(block.timestamp < ch.startTime, "Cannot join after start time");
        require(block.timestamp < ch.endTime, "Challenge ended");
        require(_stakeAmount >= MIN_AMOUNT, "Below minimum");

        if (ch.isPrivate) {
            require(
                ch.whitelist[msg.sender],
                "Not whitelisted for this challenge"
            );
        }

        Participant storage p = ch.participants[msg.sender];
        require(p.initialAmount == 0, "Already joined");

        // Calculate maximum available discount based on user's token balance
        // Each 10,000 tokens = 1 USDC discount
        uint256 userTokens = motifyToken.balanceOf(msg.sender);
        uint256 maxDiscount = 0;
        if (userTokens > 0) {
            maxDiscount = userTokens / TOKENS_PER_USDC;
            // Cap discount at stake amount
            if (maxDiscount > _stakeAmount) {
                maxDiscount = _stakeAmount;
            }
        }

        // Calculate actual payment amount after discount
        uint256 paidAmount = _stakeAmount - maxDiscount;

        // Transfer the discounted amount from user
        usdc.safeTransferFrom(msg.sender, address(this), paidAmount);

        // Process discount (burn tokens)
        if (maxDiscount > 0) {
            // Burn tokens proportional to the discount given
            uint256 tokensToBurn = maxDiscount * TOKENS_PER_USDC;
            if (tokensToBurn > userTokens) {
                tokensToBurn = userTokens;
            }
            motifyToken.burn(msg.sender, tokensToBurn);
        }

        p.initialAmount = _stakeAmount;
        p.amount = _stakeAmount;
        p.refundPercentage = 0;
        p.resultDeclared = false;

        // Track participant address
        ch.participantAddresses.push(msg.sender);
    }

    /**
     * @notice Owner declares refund percentages for a batch of participants.
     * @dev Can be called multiple times until all participants are processed. Does NOT transfer funds.
     */
    function declareResults(
        uint256 _challengeId,
        address[] calldata _participants,
        uint256[] calldata _refundPercentages
    ) external onlyOwner {
        Challenge storage ch = challenges[_challengeId];
        require(block.timestamp >= ch.endTime, "Challenge not ended yet");
        require(
            !ch.resultsFinalized,
            "Challenge results are already finalized"
        );
        require(
            _participants.length == _refundPercentages.length,
            "Array length mismatch"
        );

        for (uint i = 0; i < _participants.length; i++) {
            require(
                _refundPercentages[i] <= BASIS_POINTS_DIVISOR,
                "Invalid refund percentage"
            );

            Participant storage p = ch.participants[_participants[i]];
            require(p.initialAmount > 0, "Participant not found");
            require(
                !p.resultDeclared,
                "Result already declared for participant"
            );

            uint256 initialStake = p.initialAmount;
            uint256 refundAmount = (initialStake * _refundPercentages[i]) /
                BASIS_POINTS_DIVISOR;
            uint256 donationAmount = initialStake - refundAmount;

            ch.totalDonationAmount += donationAmount;

            if (refundAmount > 0) {
                ch.totalWinnerInitialStake += initialStake;
            }

            p.amount = refundAmount;
            p.refundPercentage = _refundPercentages[i];
            p.resultDeclared = true;
            ch.declaredParticipants++;
        }
    }

    /**
     * @notice Processes total donations and splits fees.
     * @dev Can only be called once per challenge.
     */
    function finalizeAndProcessDonations(
        uint256 _challengeId
    ) external onlyOwner {
        Challenge storage ch = challenges[_challengeId];
        require(block.timestamp >= ch.endTime, "Challenge not ended yet");
        require(!ch.resultsFinalized, "Donations have already been processed");
        require(
            ch.declaredParticipants == ch.participantAddresses.length,
            "Not all results declared"
        );

        ch.resultsFinalized = true;

        uint256 totalDonation = ch.totalDonationAmount;
        if (totalDonation > 0) {
            uint256 fee = (totalDonation * FEE_BASIS_POINTS) /
                BASIS_POINTS_DIVISOR;
            uint256 platformFee = fee / 2;
            uint256 tokenFee = fee - platformFee;
            uint256 netDonation = totalDonation - fee;

            if (ch.totalWinnerInitialStake > 0) {
                ch.tokenPot = tokenFee * TOKENS_PER_USDC;
            } else {
                platformFee += tokenFee;
            }

            collectedFees += platformFee;
            usdc.safeTransfer(ch.recipient, netDonation);
        }
    }

    /**
     * @notice Participant claims refund and receives tokens if eligible.
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

        if (refundAmount > 0) {
            require(ch.resultsFinalized, "Challenge not finalized");
            require(ch.totalWinnerInitialStake > 0, "No token pot available");
            uint256 tokensToMint = (p.initialAmount * ch.tokenPot) /
                ch.totalWinnerInitialStake;
            motifyToken.mint(msg.sender, tokensToMint);
        }
    }

    /**
     * @notice Participant claims full refund if results not declared in time.
     */
    function claimTimeoutRefund(uint256 _challengeId) external {
        Challenge storage ch = challenges[_challengeId];
        Participant storage p = ch.participants[msg.sender];

        require(!p.resultDeclared, "Results were already declared");
        require(
            block.timestamp > ch.endTime + DECLARATION_TIMEOUT,
            "Declaration period has not expired"
        );

        uint256 fullRefundAmount = p.initialAmount;
        require(fullRefundAmount > 0, "No funds to claim or already claimed");

        // Checks-Effects-Interactions: Set amount to zero before transfer
        p.amount = 0;
        p.initialAmount = 0;

        usdc.safeTransfer(msg.sender, fullRefundAmount);
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

    struct ParticipantInfo {
        address participantAddress;
        uint256 initialAmount;
        uint256 amount;
        uint256 refundPercentage;
        bool resultDeclared;
    }

    struct ChallengeInfo {
        uint256 challengeId;
        address recipient;
        uint256 startTime;
        uint256 endTime;
        bool isPrivate;
        string name;
        string apiType;
        string goalType;
        uint256 goalAmount;
        string description;
        uint256 totalDonationAmount;
        bool resultsFinalized;
        uint256 participantCount;
    }

    struct ChallengeDetail {
        uint256 challengeId;
        address recipient;
        uint256 startTime;
        uint256 endTime;
        bool isPrivate;
        string name;
        string apiType;
        string goalType;
        uint256 goalAmount;
        string description;
        uint256 totalDonationAmount;
        bool resultsFinalized;
        ParticipantInfo[] participants;
    }

    /**
     * @notice Get detailed information about a specific challenge including all participants
     * @param _challengeId The ID of the challenge
     * @return ChallengeDetail struct with full challenge and participant data
     */
    function getChallengeById(
        uint256 _challengeId
    ) external view returns (ChallengeDetail memory) {
        require(_challengeId < nextChallengeId, "Challenge does not exist");

        Challenge storage ch = challenges[_challengeId];

        // Build participants array
        uint256 participantCount = ch.participantAddresses.length;
        ParticipantInfo[] memory participantInfos = new ParticipantInfo[](
            participantCount
        );

        for (uint256 i = 0; i < participantCount; i++) {
            address participantAddr = ch.participantAddresses[i];
            Participant storage p = ch.participants[participantAddr];
            participantInfos[i] = ParticipantInfo({
                participantAddress: participantAddr,
                initialAmount: p.initialAmount,
                amount: p.amount,
                refundPercentage: p.refundPercentage,
                resultDeclared: p.resultDeclared
            });
        }

        return
            ChallengeDetail({
                challengeId: _challengeId,
                recipient: ch.recipient,
                startTime: ch.startTime,
                endTime: ch.endTime,
                isPrivate: ch.isPrivate,
                name: ch.name,
                apiType: ch.apiType,
                goalType: ch.goalType,
                goalAmount: ch.goalAmount,
                description: ch.description,
                totalDonationAmount: ch.totalDonationAmount,
                resultsFinalized: ch.resultsFinalized,
                participants: participantInfos
            });
    }

    /**
     * @notice Get the latest challenges (up to 100)
     * @param _limit Maximum number of challenges to return (capped at 100)
     * @return Array of ChallengeInfo structs
     */
    function getAllChallenges(
        uint256 _limit
    ) external view returns (ChallengeInfo[] memory) {
        uint256 limit = _limit > 100 ? 100 : _limit;
        uint256 totalChallenges = nextChallengeId;
        uint256 resultCount = totalChallenges < limit ? totalChallenges : limit;

        ChallengeInfo[] memory challengeInfos = new ChallengeInfo[](
            resultCount
        );

        // Get the latest challenges (reverse order)
        for (uint256 i = 0; i < resultCount; i++) {
            uint256 challengeId = totalChallenges - 1 - i;
            Challenge storage ch = challenges[challengeId];

            challengeInfos[i] = ChallengeInfo({
                challengeId: challengeId,
                recipient: ch.recipient,
                startTime: ch.startTime,
                endTime: ch.endTime,
                isPrivate: ch.isPrivate,
                name: ch.name,
                apiType: ch.apiType,
                goalType: ch.goalType,
                goalAmount: ch.goalAmount,
                description: ch.description,
                totalDonationAmount: ch.totalDonationAmount,
                resultsFinalized: ch.resultsFinalized,
                participantCount: ch.participantAddresses.length
            });
        }

        return challengeInfos;
    }

    /**
     * @notice Get all challenges where a specific address is a participant
     * @param _participant The wallet address to filter by
     * @return Array of ChallengeInfo structs for challenges the address participated in
     */
    function getChallengesForParticipant(
        address _participant
    ) external view returns (ChallengeInfo[] memory) {
        // First pass: count how many challenges the participant is in
        uint256 count = 0;
        for (uint256 i = 0; i < nextChallengeId; i++) {
            if (
                challenges[i].participants[_participant].initialAmount > 0 ||
                challenges[i].participants[_participant].resultDeclared
            ) {
                count++;
            }
        }

        // Second pass: populate the array
        ChallengeInfo[] memory challengeInfos = new ChallengeInfo[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < nextChallengeId; i++) {
            Challenge storage ch = challenges[i];
            if (
                ch.participants[_participant].initialAmount > 0 ||
                ch.participants[_participant].resultDeclared
            ) {
                challengeInfos[index] = ChallengeInfo({
                    challengeId: i,
                    recipient: ch.recipient,
                    startTime: ch.startTime,
                    endTime: ch.endTime,
                    isPrivate: ch.isPrivate,
                    name: ch.name,
                    apiType: ch.apiType,
                    goalType: ch.goalType,
                    goalAmount: ch.goalAmount,
                    description: ch.description,
                    totalDonationAmount: ch.totalDonationAmount,
                    resultsFinalized: ch.resultsFinalized,
                    participantCount: ch.participantAddresses.length
                });
                index++;
            }
        }

        return challengeInfos;
    }

    /**
     * @notice Get participant information for a specific challenge and address
     * @param _challengeId The ID of the challenge
     * @param _participant The address of the participant
     * @return ParticipantInfo struct with participant data
     */
    function getParticipantInfo(
        uint256 _challengeId,
        address _participant
    ) external view returns (ParticipantInfo memory) {
        require(_challengeId < nextChallengeId, "Challenge does not exist");

        Challenge storage ch = challenges[_challengeId];
        Participant storage p = ch.participants[_participant];

        return
            ParticipantInfo({
                participantAddress: _participant,
                initialAmount: p.initialAmount,
                amount: p.amount,
                refundPercentage: p.refundPercentage,
                resultDeclared: p.resultDeclared
            });
    }
}
