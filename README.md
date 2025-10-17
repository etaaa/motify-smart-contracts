# Motify Smart Contracts

A stake-based challenge system where users commit USDC tokens and receive refunds based on their performance.

## Contracts

**Motify.sol**: Main contract for creating and managing challenges
- Create public or private (whitelisted) challenges
- Stake USDC tokens to join
- Owner declares refund percentages (0-100%) after challenge ends
- Unclaimed portions go to designated recipient with 10% platform fee

**MockUSDC.sol**: Test token for development (6 decimals, 1M supply)

## Quick Start (Remix)

1. Open [Remix IDE](https://remix.ethereum.org)
2. Upload both contracts from `/contracts`
3. Compile with Solidity ^0.8.20
4. Deploy **MockUSDC** first
5. Deploy **Motify** with the MockUSDC address
6. Mint/approve tokens, then call `joinChallenge()`