// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @notice This is a mock version of USDC, created for local testing and development only.
 * @dev Do NOT use this contract in production or on mainnet.
 * It mints test tokens to the deployer so you can simulate USDC behavior in Remix or testnets.
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1_000_000 * 10 ** 6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
