# Motify Smart Contracts

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

## Contracts
- `Motify.sol`: Main contract for creating and managing challenges, handling stakes, refunds, and token rewards
- `MotifyToken.sol` & `IMotifyToken.sol`: ERC20 token for rewarding winners, minting and burning controlled by Motify
- `MockUSDC.sol`: Mock USDC token for testing

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