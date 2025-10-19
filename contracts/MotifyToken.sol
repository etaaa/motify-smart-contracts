// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IMotifyToken.sol";

/**
 * @title MotifyToken
 * @notice Simple ERC20 token with mint and burn controlled by the Motify contract.
 */
contract MotifyToken is ERC20, IMotifyToken {
    address public immutable motify;
    address public immutable owner;

    modifier onlyMotify() {
        require(msg.sender == motify, "Not authorized");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(address _motify) ERC20("Motify Token", "MOTIFY") {
        require(_motify != address(0), "Motify address cannot be zero");
        motify = _motify;
        owner = msg.sender;
    }

    /**
     * @notice Mint tokens for testing purposes
     * @param amount The amount of tokens to mint to the caller
     * TODO: Remove this function in production
     */
    function mintForTesting(uint256 amount) external onlyOwner {
        _mint(msg.sender, amount);
    }

    function mint(address to, uint256 amount) external override onlyMotify {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external override onlyMotify {
        _burn(from, amount);
    }

    // Explicitly override balanceOf to resolve conflict between ERC20 and IMotifyToken
    function balanceOf(
        address account
    ) public view override(ERC20, IMotifyToken) returns (uint256) {
        return super.balanceOf(account);
    }

    // Explicitly override totalSupply to resolve conflict between ERC20 and IMotifyToken
    function totalSupply()
        public
        view
        override(ERC20, IMotifyToken)
        returns (uint256)
    {
        return super.totalSupply();
    }
}
