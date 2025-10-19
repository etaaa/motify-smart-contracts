// Minimal deployment script for Base Sepolia
const hre = require("hardhat");

async function main() {
    const networkName = hre.network.name;
    console.log(`Deploying to network: ${networkName}`);

    const [deployer] = await hre.ethers.getSigners();
    console.log("Deployer:", deployer.address);

    // Inputs from env
    const ADDITIONAL_OWNER = process.env.ADDITIONAL_OWNER || deployer.address;

    // Prepare EIP-1559 fee overrides (bump suggested fees slightly to avoid underpriced replacements)
    const feeData = await hre.ethers.provider.getFeeData();
    const defaultMaxFee = hre.ethers.parseUnits("50", "gwei");
    const defaultPriority = hre.ethers.parseUnits("2", "gwei");
    const maxFeePerGas = feeData.maxFeePerGas ? (feeData.maxFeePerGas * 12n) / 10n : defaultMaxFee;
    const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas ? (feeData.maxPriorityFeePerGas * 12n) / 10n : defaultPriority;
    const overrides = { maxFeePerGas, maxPriorityFeePerGas };
    console.log(
        `Using fees -> maxFeePerGas: ${maxFeePerGas} wei, maxPriorityFeePerGas: ${maxPriorityFeePerGas} wei`
    );
    const delay = (ms) => new Promise((res) => setTimeout(res, ms));

    // 1) Deploy MockUSDC
    const MockUSDC = await hre.ethers.getContractFactory("MockUSDC");
    const usdc = await MockUSDC.deploy(overrides);
    await usdc.waitForDeployment();
    const usdcAddress = await usdc.getAddress();
    console.log("MockUSDC deployed at:", usdcAddress);
    await delay(500);

    // 2) Deploy Motify(usdc, additionalOwner)
    const Motify = await hre.ethers.getContractFactory("Motify");
    const motify = await Motify.deploy(usdcAddress, ADDITIONAL_OWNER, overrides);
    await motify.waitForDeployment();
    const motifyAddress = await motify.getAddress();
    console.log("Motify deployed at:", motifyAddress);
    await delay(500);

    // 3) Deploy MotifyToken(motify)
    const MotifyToken = await hre.ethers.getContractFactory("MotifyToken");
    const token = await MotifyToken.deploy(motifyAddress, overrides);
    await token.waitForDeployment();
    const tokenAddress = await token.getAddress();
    console.log("MotifyToken deployed at:", tokenAddress);
    await delay(500);

    // Wire token to Motify
    const tx = await motify.setTokenAddress(tokenAddress, overrides);
    await tx.wait();
    console.log("Motify token address set.");

    // Optional: small delay to allow explorers to index
    console.log("Waiting 30s before verification...");
    await delay(500);

    // Verify contracts
    try {
        await hre.run("verify:verify", {
            address: usdcAddress,
            constructorArguments: [],
        });
        console.log("Verified MockUSDC");
    } catch (err) {
        console.log("Verification skipped/failed for MockUSDC:", err.message || err);
    }

    try {
        await hre.run("verify:verify", {
            address: motifyAddress,
            constructorArguments: [usdcAddress, ADDITIONAL_OWNER],
        });
        console.log("Verified Motify");
    } catch (err) {
        console.log("Verification skipped/failed for Motify:", err.message || err);
    }

    try {
        await hre.run("verify:verify", {
            address: tokenAddress,
            constructorArguments: [motifyAddress],
        });
        console.log("Verified MotifyToken");
    } catch (err) {
        console.log("Verification skipped/failed for MotifyToken:", err.message || err);
    }

    return { usdc: usdcAddress, motify: motifyAddress, token: tokenAddress };
}

main()
    .then((addresses) => {
        console.log("Deployment complete:", addresses);
        process.exit(0);
    })
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
