// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Simple ERC20 contract
 * @author Alexander Scherbatyuk
 * @notice This is a simple ERC20 contract with 100% test coverage example
 */
contract MockToken is ERC20 {
    uint8 s_decimal;

    constructor(string memory name, string memory symbol, address initialAccount, uint256 initialBalance, uint8 decimal) payable ERC20(name, symbol) {
        s_decimal = decimal;
        _mint(initialAccount, initialBalance);
    }

    function decimals() public view override returns (uint8) {
        return s_decimal;
    }
}

/**
 * @title FailingMockToken
 * @notice A mock ERC20 token that can be configured to fail transfers for testing purposes
 */
contract FailingMockToken is ERC20 {
    bool public shouldFailTransfer = false;

    constructor(uint256 initialSupply) ERC20("FailingMockToken", "FMT") {
        _mint(msg.sender, initialSupply);
    }

    function setShouldFailTransfer(bool _shouldFail) external {
        shouldFailTransfer = _shouldFail;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (shouldFailTransfer) {
            return false;
        }
        return super.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (shouldFailTransfer) {
            return false;
        }
        return super.transfer(to, amount);
    }
}
