const hre = require("hardhat");

// Helper to deploy a contract and log its address
async function deploy(contractName, args = [], overrides = {}) {
    const ContractFactory = await hre.ethers.getContractFactory(contractName);
    const contract = await ContractFactory.deploy(...args, overrides);
    await contract.waitForDeployment();
    const address = await contract.getAddress();
    console.log(`${contractName.padEnd(10)}: ${address}`);
    return { contract, address };
}

// Helper to verify a contract on Etherscan
async function verify(address, args = []) {
    try {
        await hre.run("verify:verify", { address, constructorArguments: args });
        console.log(`Verified: ${address}`);
    } catch (error) {
        if (!error.message.includes("Already Verified")) {
            console.error(`Verification failed for ${address}:`, error.message);
        }
    }
}

async function main() {
    const networkName = hre.network.name;
    const [deployer] = await hre.ethers.getSigners();

    console.log(`Network: ${networkName}`);
    console.log(`Deployer: ${deployer.address}`);

    // Inputs from env
    const ADDITIONAL_OWNER = process.env.ADDITIONAL_OWNER || deployer.address;

    // Quiet EIP-1559 overrides (slightly bump fees)
    const feeData = await hre.ethers.provider.getFeeData();
    const defaultMaxFee = hre.ethers.parseUnits("50", "gwei");
    const defaultPriority = hre.ethers.parseUnits("2", "gwei");
    const maxFeePerGas = feeData.maxFeePerGas ? (feeData.maxFeePerGas * 12n) / 10n : defaultMaxFee;
    const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas ? (feeData.maxPriorityFeePerGas * 12n) / 10n : defaultPriority;

    // Get the initial nonce
    let nonce = await hre.ethers.provider.getTransactionCount(deployer.address, "latest");

    const overrides = (n) => ({ maxFeePerGas, maxPriorityFeePerGas, nonce: n });

    console.log("Deploying...");

    // 1) MockUSDC
    const { address: usdcAddress } = await deploy("MockUSDC", [], overrides(nonce++));

    // 2) Motify(usdc, additionalOwner)
    const { contract: motify, address: motifyAddress } = await deploy("Motify", [usdcAddress, ADDITIONAL_OWNER], overrides(nonce++));

    // 3) MotifyToken(motify)
    const { address: tokenAddress } = await deploy("MotifyToken", [motifyAddress], overrides(nonce++));

    // Wire token to Motify
    const tx = await motify.setTokenAddress(tokenAddress, overrides(nonce++));
    await tx.wait();
    console.log("Linked:   Motify <-> Token");

    // Verify (quiet on failures)
    console.log("Verifying (may be skipped if already verified)...");
    await verify(usdcAddress);
    await verify(motifyAddress, [usdcAddress, ADDITIONAL_OWNER]);
    await verify(tokenAddress, [motifyAddress]);

    return { usdc: usdcAddress, motify: motifyAddress, token: tokenAddress };
} main()
    .then((addresses) => {
        console.log("Addresses:");
        console.log(JSON.stringify(addresses, null, 2));
        process.exit(0);
    })
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
