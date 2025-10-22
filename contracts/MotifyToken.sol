// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IMotifyToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MotifyToken
 * @notice Simple ERC20 token with mint and burn controlled by the Motify contract.
 */
contract MotifyToken is IMotifyToken, ERC20 {
    address public immutable motify;

    modifier onlyMotify() {
        require(msg.sender == motify, "Not authorized");
        _;
    }

    constructor(address _motify) ERC20("Motify Token", "MOTIFY") {
        require(_motify != address(0), "Motify address cannot be zero");
        motify = _motify;
    }

    function mint(address to, uint256 amount) external override onlyMotify {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external override onlyMotify {
        _burn(from, amount);
    }

    function balanceOf(
        address account
    ) public view override(ERC20, IMotifyToken) returns (uint256) {
        return super.balanceOf(account);
    }
}
