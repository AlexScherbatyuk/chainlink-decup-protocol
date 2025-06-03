// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Simple ERC20 contract
 * @author Alexander Scherbatyuk
 * @notice This is a simple ERC20 contract with 100% test coverage example
 */
contract MockToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("MockToken", "MT") {
        _mint(msg.sender, initialSupply);
    }
}
