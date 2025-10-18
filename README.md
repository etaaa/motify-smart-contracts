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

## Step-by-Step Tutorial: Testing Motify Contracts

1. **Open Remix IDE**
	- Go to [Remix IDE](https://remix.ethereum.org) in your browser.

2. **Upload Contracts**
	- Drag and drop all files from the `contracts/` folder (`Motify.sol`, `MotifyToken.sol`, `IMotifyToken.sol`, `MockUSDT.sol`) into Remix.

3. **Compile Contracts**
	- Set the Solidity compiler version to `^0.8.20`.
	- Compile each contract.

4. **Deploy Mock USDC**
	- Deploy `MockUSDC.sol`.
	- This gives you test USDC tokens.

5. **Deploy Motify Contract**
	- Deploy `Motify.sol`, passing the address of the deployed Mock USDC contract as the constructor argument.

6. **Deploy MotifyToken Contract**
	- Deploy `MotifyToken.sol`, passing the address of the deployed Motify contract as the constructor argument.

7. **Set MotifyToken in Motify**
	- In Remix, call the function on Motify to set the MotifyToken contract address.

8. **Mint and Approve USDC**
	- Use the Mock USDC contract to mint tokens to your test account.
	- Approve the Motify contract to spend your USDC using the `approve` function in Mock USDC.

9. **Create a Challenge**
	- Use Motify’s function to create a new challenge. Provide required parameters.

10. **Join a Challenge**
	 - Call the join function in Motify, staking USDC.

11. **Declare Results**
	 - As the challenge creator, declare results for participants.

12. **Claim Refunds and Rewards**
	 - Participants can claim their USDC refunds and Motify token rewards.

13. **Burn Motify Tokens for Discounts**
	 - Use MotifyToken’s `burn` function to burn tokens.