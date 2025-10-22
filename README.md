# Motify Smart Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hardhat](https://img.shields.io/badge/Built%20with-Hardhat-FFDB1C.svg)](https://hardhat.org/)

## Table of Contents

- [Project Background](#project-background)
- [Introduction](#introduction)
- [Features](#features)
- [Architecture](#architecture)
- [Local Development](#local-development)
- [Contributing](#contributing)
- [License](#license)

## Project Background
Motify was created for the START Vienna Hackathon 2025, where it won first place. The project is now deployed on Base and being submitted for the Base Batches program.

## Introduction
Motify is a stake-based challenge system on Base (an Ethereum L2). Users commit USDC tokens to challenges and receive refunds based on their performance. Winners are rewarded with Motify tokens.

## Features

- **Stake-Based Challenges:** Stake USDC to join public or private challenges.
- **Performance-Based Refunds:** Get back 0–100% of your stake depending on your challenge results.
- **Proportional Token Rewards:** Winners receive a share of a token pot, funded by a portion of the fees from non-winning stakes.
- **Discounts via Token Burn:** Burn Motify tokens to reduce the USDC required to join new challenges.
- **Donation Fee Structure:** A 10% fee is applied to all non-refunded stakes (donations), which is then split between the platform and the token reward pool.
- **Automatic Timeout Protection:** If results aren’t declared within 7 days of the challenge ending, participants can claim a full refund.

## Architecture

The Motify protocol is composed of three main contracts:

-   **`Motify.sol`**: This is the core contract that orchestrates the challenge logic. It handles challenge creation, user participation (staking), result declaration, and the distribution of refunds and rewards. It holds the staked USDC in escrow during a challenge.

-   **`MotifyToken.sol`**: An ERC20 token that is rewarded to challenge winners. The `Motify` contract has the exclusive right to mint these tokens. The contract also includes a `burn` function that allows users to get discounts on future challenges.

-   **`MockUSDC.sol`** (for testing only): A mock ERC20 token that mimics USDC for testing purposes in a local development environment. It provides a `mint` function to allow test accounts to get tokens freely.

## Local Development

### Prerequisites

- [Node.js](https://nodejs.org/en/) (v18 or later)
- [npm](https://www.npmjs.com/)

### Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/etaaa/motify-smart-contract.git
   cd motify-smart-contract
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Create environment file:**
   Create a `.env` file in the root of the project and add the following environment variables.
   ```
   PRIVATE_KEY="<your-private-key>"
   ETHERSCAN_API_KEY="<your-etherscan-api-key>"
   USDC_ADDRESS="<usdc-contract-address-for-mainnet>"
   ```
   Note: For Base mainnet, use `USDC_ADDRESS=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`. For testnets, leave it empty to deploy MockUSDC.

### Compile

Compile the smart contracts:
```bash
npm run compile
```

### Test

Run the test suite:
```bash
npm test
```

### Deployment

Deploy to Base Sepolia testnet:
```bash
npm run deploy:base-sepolia
```

Deploy to Base mainnet:
```bash
npm run deploy:base
```

### Contract Verification

Verify contracts on Basescan:
```bash
npx hardhat verify --network baseSepolia <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
npx hardhat verify --network base <CONTRACT_ADDRESS> <CONSTRUCTOR_ARGS>
```

## Contributing

Contributions are welcome! If you'd like to contribute, please follow these steps:

1.  Fork the repository.
2.  Create a new branch (`git checkout -b feature/your-feature-name`).
3.  Make your changes.
4.  Commit your changes (`git commit -m 'Add some feature'`).
5.  Push to the branch (`git push origin feature/your-feature-name`).
6.  Open a pull request.

Please make sure to update tests as appropriate.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
