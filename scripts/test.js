const hre = require("hardhat");

// Helper function to format USDC amounts (6 decimals)
function toUsdc(amount) {
    return hre.ethers.parseUnits(amount.toString(), 6);
}

// Helper function to format USDC for display
function displayUsdc(amount) {
    return hre.ethers.formatUnits(amount, 6);
}

// Helper function to format tokens (18 decimals)
function displayTokens(amount) {
    return hre.ethers.formatUnits(amount, 18);
}

// Helper function to increase time in local network
async function increaseTime(seconds) {
    await hre.network.provider.send("evm_increaseTime", [seconds]);
    await hre.network.provider.send("evm_mine");
}

async function main() {
    console.log("Motify test: start");

    // Accounts
    const [deployer, recipient, user1, user2, user3] = await hre.ethers.getSigners();

    // Deploy contracts
    const MockUSDC = await hre.ethers.getContractFactory("MockUSDC");
    const usdc = await MockUSDC.deploy();
    await usdc.waitForDeployment();
    const usdcAddress = await usdc.getAddress();

    const Motify = await hre.ethers.getContractFactory("Motify");
    const motify = await Motify.deploy(usdcAddress);
    await motify.waitForDeployment();
    const motifyAddress = await motify.getAddress();

    const MotifyToken = await hre.ethers.getContractFactory("MotifyToken");
    const token = await MotifyToken.deploy(motifyAddress);
    await token.waitForDeployment();
    const tokenAddress = await token.getAddress();

    await motify.setTokenAddress(tokenAddress);

    console.log("Deployed:");
    console.log(`- MockUSDC     ${usdcAddress}`);
    console.log(`- Motify       ${motifyAddress}`);
    console.log(`- MotifyToken  ${tokenAddress}`);

    // Fund users
    const user1Amount = toUsdc(100);
    const user2Amount = toUsdc(50);
    const user3Amount = toUsdc(25);
    await usdc.transfer(user1.address, user1Amount);
    await usdc.transfer(user2.address, user2Amount);
    await usdc.transfer(user3.address, user3Amount);

    // Create challenge (public)
    const now = Math.floor(Date.now() / 1000);
    const startTime = now + 60;
    const endTime = startTime + 7 * 24 * 60 * 60; // 7 days
    await (await motify.createChallenge(
        recipient.address,
        startTime,
        endTime,
        false,
        "30 Day Fitness Challenge",
        "steps",
        "daily_average",
        10000,
        "Walk 10,000 steps daily for 30 days",
        []
    )).wait();
    const challengeId = 0;

    // Users join
    await usdc.connect(user1).approve(motifyAddress, user1Amount);
    await motify.connect(user1).joinChallenge(challengeId, user1Amount);
    await usdc.connect(user2).approve(motifyAddress, user2Amount);
    await motify.connect(user2).joinChallenge(challengeId, user2Amount);
    await usdc.connect(user3).approve(motifyAddress, user3Amount);
    await motify.connect(user3).joinChallenge(challengeId, user3Amount);

    // Fast forward to end and declare results (U1:100%, U2:80%, U3:0%)
    const timeToSkip = endTime - now + 10;
    await increaseTime(timeToSkip);
    await (await motify.declareResults(
        challengeId,
        [user1.address, user2.address, user3.address],
        [10000, 8000, 0]
    )).wait();

    // Finalize donations
    const recipientBalanceBefore = await usdc.balanceOf(recipient.address);
    await (await motify.finalizeAndProcessDonations(challengeId)).wait();
    const recipientBalanceAfter = await usdc.balanceOf(recipient.address);
    const recipientReceived = recipientBalanceAfter - recipientBalanceBefore;

    // Claims
    const user1UsdcBefore = await usdc.balanceOf(user1.address);
    const user1TokBefore = await token.balanceOf(user1.address);
    await (await motify.connect(user1).claimRefund(challengeId)).wait();
    const user1UsdcAfter = await usdc.balanceOf(user1.address);
    const user1TokAfter = await token.balanceOf(user1.address);
    const user1Refund = user1UsdcAfter - user1UsdcBefore;
    const user1Tokens = user1TokAfter - user1TokBefore;

    const user2UsdcBefore = await usdc.balanceOf(user2.address);
    const user2TokBefore = await token.balanceOf(user2.address);
    await (await motify.connect(user2).claimRefund(challengeId)).wait();
    const user2UsdcAfter = await usdc.balanceOf(user2.address);
    const user2TokAfter = await token.balanceOf(user2.address);
    const user2Refund = user2UsdcAfter - user2UsdcBefore;
    const user2Tokens = user2TokAfter - user2TokBefore;

    // Summary
    const totalStaked = user1Amount + user2Amount + user3Amount;
    const collectedFees = await motify.collectedFees();

    console.log("\nSummary:");
    console.log(`- Total staked:   ${displayUsdc(totalStaked)} USDC`);
    console.log(`- Recipient got:  ${displayUsdc(recipientReceived)} USDC (net)`);
    console.log(`- User1 refund:   ${displayUsdc(user1Refund)} USDC, tokens: ${displayTokens(user1Tokens)} MTFY`);
    console.log(`- User2 refund:   ${displayUsdc(user2Refund)} USDC, tokens: ${displayTokens(user2Tokens)} MTFY`);
    console.log(`- User3 refund:   0 USDC, tokens: 0 MTFY`);
    console.log(`- Platform fees:  ${displayUsdc(collectedFees)} USDC`);
    console.log("Motify test: done");
}

main()
    .then(() => {
        console.log("Success");
        process.exit(0);
    })
    .catch((error) => {
        console.error("Test failed:");
        console.error(error);
        process.exit(1);
    });
