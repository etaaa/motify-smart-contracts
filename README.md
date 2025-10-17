# Motify Contracts

Smart contracts for the Motify challenge and staking system.

## Overview

- `Motify.sol`: Main contract that manages challenges and stakes.
- `MockUSDT.sol`: A mock ERC20 token (for local testing only).

## Development

These contracts can be tested directly in [Remix](https://remix.ethereum.org) or locally using a Solidity development framework such as Hardhat or Foundry.

## Testing in Remix

1. Open Remix IDE

2. Upload the following files:
    - Motify.sol
    - MockUSDT.sol
	
3. Compile both contracts using Solidity ^0.8.20

4. Deploy MockUSDT first

5. Deploy Motify, passing the MockUSDT contract address to the constructor

6. Use approve() on the mock token, then call joinChallenge() in the Motify contract