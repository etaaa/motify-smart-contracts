require("dotenv").config();

require("@nomicfoundation/hardhat-toolbox");

const {
    PRIVATE_KEY = "",
    ETHERSCAN_API_KEY = "",
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
            url: "https://sepolia.base.org",
            accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
            chainId: 84532,
        },
        base: {
            url: "https://mainnet.base.org",
            accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
            chainId: 8453,
        },
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY || "",
        customChains: [
            {
                network: "baseSepolia",
                chainId: 84532,
                urls: {
                    apiURL: "https://api-sepolia.basescan.org/api",
                    browserURL: "https://sepolia.basescan.org"
                }
            },
            {
                network: "base",
                chainId: 8453,
                urls: {
                    apiURL: "https://api.basescan.org/api",
                    browserURL: "https://basescan.org"
                }
            }
        ]
    },
};
