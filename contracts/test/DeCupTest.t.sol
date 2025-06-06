// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DeCup} from "src/DeCup.sol";
import {DeployDeCup} from "script/DeployDeCup.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockToken} from "./mocks/MockToken.sol";

contract DeCupTest is Test {
    DeCup public deCup;
    MockToken public mockToken;
    address public USER = makeAddr("user");
    uint256 public constant INITIAL_BALANCE = 1000 ether;

    function setUp() external {
        string memory svgDeCup = vm.readFile("./img/decup.svg");
        DeployDeCup deployer = new DeployDeCup();
        deCup = deployer.deployDeCup(svgDeCup);
        mockToken = new MockToken(1000 ether);

        // Fund the user
        vm.deal(USER, INITIAL_BALANCE);
        mockToken.transfer(USER, INITIAL_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                         ERC20 NATIVE CURRENCY
    //////////////////////////////////////////////////////////////*/

    function testReceiveNative() public {
        // Arrange
        uint256 amount = 1 ether;

        // Act
        vm.prank(USER);
        (bool success,) = address(deCup).call{value: amount}("");

        // Assert
        assert(success);
        assertEq(address(deCup).balance, amount);
    }

    function testReceiveNativeZeroAmount() public {
        // Arrange
        uint256 amount = 0;

        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        (bool success,) = address(deCup).call{value: amount}("");
        assert(success);
    }

    // First deposit some ETH
    function testWithdrawNative() public {
        // Arrange
        uint256 initialBalance = USER.balance;
        uint256 withdrawAmount = 0.5 ether;
        vm.deal(address(deCup), 1 ether);

        // Act
        vm.prank(USER);
        deCup.withdrawNative(withdrawAmount);

        // Assert
        assertEq(USER.balance, initialBalance + withdrawAmount);
        assertEq(address(deCup).balance, 0.5 ether);
    }

    function testWithdrawNativeZeroAmount() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        deCup.withdrawNative(0);
    }

    function testWithdrawNativeInsufficientBalance() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(DeCup.DeCup__InsufficientBalance.selector);
        deCup.withdrawNative(1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                       ERC20 DEPOSIT / WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    function testDepositeERC20() public {
        // Arrange
        uint256 amount = 1000 * 10 ** 18;

        // Act
        vm.startPrank(USER);
        mockToken.approve(address(deCup), amount);
        deCup.depositeERC20(address(mockToken), amount);
        vm.stopPrank();

        // Assert
        assertEq(mockToken.balanceOf(address(deCup)), amount);
    }

    function testWithdrawERC20() public {
        // Arrange
        uint256 initialBalance = mockToken.balanceOf(USER);
        uint256 withdrawAmount = 500 * 10 ** 18;

        // Act
        vm.startPrank(USER);
        mockToken.transfer(address(deCup), 500 * 10 ** 18);
        deCup.withdrawERC20(address(mockToken), withdrawAmount);
        vm.stopPrank();

        // Assert
        assertEq(mockToken.balanceOf(USER), initialBalance);
        assertEq(mockToken.balanceOf(address(deCup)), 0);
    }

    function testWithdrawERC20ZeroAmount() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        deCup.withdrawERC20(address(mockToken), 0);
    }

    function testWithdrawERC20InsufficientBalance() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(DeCup.DeCup__InsufficientBalance.selector);
        deCup.withdrawERC20(address(mockToken), 1000 * 10 ** 18);
    }

    function testDepositeERC20ZeroAmount() public {
        // Arrange
        vm.startPrank(USER);
        // Act / Assert
        mockToken.approve(address(deCup), 1000 * 10 ** 18);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        deCup.depositeERC20(address(mockToken), 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              NFT TESTING
    //////////////////////////////////////////////////////////////*/

    function testMintNft() public {}
}
