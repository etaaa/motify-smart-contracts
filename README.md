# Motify Smart Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hardhat](https://img.shields.io/badge/Built%20with-Hardhat-FFDB1C.svg)](https://hardhat.org/)

## Table of Contents

- [Project Background](#project-background)
- [Introduction](#introduction)
- [Features](#features)
- [Architecture](#architecture)
- [Deployed Contracts](#deployed-contracts)
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
- **Token Rewards:** Winners receive Motify tokens (10,000 MOTIFY per USDC refunded).
- **Discounts via Token Burn:** Burn Motify tokens to reduce the USDC required to join new challenges.
- **One-Click Join (EIP-2612):** Join challenges in a single transaction using permit (no separate approval needed).
- **Donation Fee Structure:** 10% fee on donations (split: 5% to platform, 5% to token backing pool).
- **Automatic Timeout Protection:** If results aren’t declared within 7 days, participants are auto-refunded.

## Architecture

The Motify protocol is composed of three main contracts:

-   **`Motify.sol`**: This is the core contract that orchestrates the challenge logic. It handles challenge creation, user participation (staking), result declaration, and the distribution of refunds and rewards. It holds the staked USDC in escrow during a challenge.

-   **`MotifyToken.sol`**: An ERC20 token that is rewarded to challenge winners. The `Motify` contract has the exclusive right to mint new `MotifyToken`s. The token also includes a `burn` function that allows users to get discounts on future challenges.

-   **`MockUSDC.sol`**: A mock ERC20 token that mimics USDC for testing purposes in a local development environment. It provides a `mint` function to allow test accounts to get tokens freely.

## Deployed Contracts

You can find the deployed contracts at the following addresses:

-   **Base Mainnet:**
    -   `Motify.sol`: `0x...`
    -   `MotifyToken.sol`: `0x...`
-   **Base Sepolia (Testnet):**
    -   `Motify.sol`: `0x53Da03A36Aa9333C41C5521A113d0f8BA028bC43`
    -   `MotifyToken.sol`: `0xc19112393585Af1250352AF7B4EDdc23d8a55c3a`

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
   BASE_SEPOLIA_RPC_URL="<your-base-sepolia-rpc-url>"
   PRIVATE_KEY="<your-private-key>"
   BASESCAN_API_KEY="<your-basescan-api-key>"
   ```

### Compile

Compile the smart contracts:
```bash
npx hardhat compile
```

### Test

Run the test suite:
```bash
npx hardhat test
```

### Deployment

To deploy the contracts to a network, first configure your `hardhat.config.js` with the desired network and a private key.

Then, run the deployment script:
```bash
npx hardhat run scripts/deploy.js --network <your-network-name>
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
