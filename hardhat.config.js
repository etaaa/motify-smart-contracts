require("dotenv").config();

require("@nomicfoundation/hardhat-toolbox");

const {
    BASE_SEPOLIA_RPC_URL = "",
    PRIVATE_KEY = "",
    BASESCAN_API_KEY = "",
} = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.20",
        settings: {
            optimizer: { enabled: true, runs: 200 },
            viaIR: true,
        },
    },
    networks: {
        baseSepolia: {
            url: BASE_SEPOLIA_RPC_URL || "https://sepolia.base.org",
            accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
            chainId: 84532,
        },
    },
    etherscan: {
        apiKey: BASESCAN_API_KEY || "",
    },
};
