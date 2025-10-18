# Motify Smart Contracts

## Project Background
Motify was created for the START Vienna Hackathon 2025, where it won first place. The project is now deployed on Base and being submitted for the Base Batches program.

## Introduction
Motify is a stake-based challenge system on Base (an Ethereum L2). Users commit USDC tokens to challenges and receive refunds based on their performance. Winners are rewarded with Motify tokens.

## Features

- Stake-Based Challenges: Users stake USDC to participate in public or private challenges
- Performance-Based Refunds: Receive 0-100% refunds based on challenge performance
- Token Rewards: Winners earn Motify tokens (10,000 MTF per USDC refunded)
- Token-Backed Discounts: Burn Motify tokens to reduce stake amounts when joining challenges
- EIP-2612 Permit Support: Join challenges without needing a separate approval transaction
- Fee Structure: 10% fee on donations (5% platform, 5% token backing pool)
- Timeout Protection: Auto-refunds if results not declared within 7 days

## Contracts


## Contracts
- `Motify.sol`: Main contract for creating and managing challenges, handling stakes, refunds, and token rewards
- `MotifyToken.sol` & `IMotifyToken.sol`: ERC20 token for rewarding winners, minting and burning controlled by Motify
- `MockUSDT.sol`: Mock USDT token for testing

## Getting Started
1. Open [Remix IDE](https://remix.ethereum.org)
2. Upload all contracts from `/contracts`
3. Compile with Solidity ^0.8.20
4. Deploy `MockUSDT` first
5. Deploy `Motify` with `MockUSDT` address
6. Deploy `MotifyToken` with `Motify` contract address
7. Mint/approve tokens, then join or create a challenge