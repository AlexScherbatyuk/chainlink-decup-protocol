// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test,console} from "forge-std/Test.sol";
import {DeCupNft} from "src/DeCupNft.sol";
import {DeployDeCupNft} from "script/DeployDeCupNft.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockToken} from "./mocks/MockToken.sol";


contract DeCupTest is Test {
    DeCupNft public deCupNft;
    MockToken public mockToken;
    address public USER = makeAddr("user");
    uint256 public constant INITIAL_BALANCE = 1000 ether;

    function setUp() external {
        DeployDeCupNft deployer = new DeployDeCupNft();
        deCupNft = deployer.deployDeCupNft();
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
        (bool success, ) = address(deCupNft).call{value: amount}("");
        
        // Assert
        assert(success);
        assertEq(address(deCupNft).balance, amount);

    }

    function testReceiveNativeZeroAmount() public {
        // Arrange
        uint256 amount = 0;
        
        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(DeCupNft.DeCupNft__AmountMustBeGreaterThanZero.selector);
        (bool success, ) = address(deCupNft).call{value: amount}("");
        assert(success);

    }

    // First deposit some ETH
    function testWithdrawNative() public {
        // Arrange
        uint256 initialBalance = USER.balance;
        uint256 withdrawAmount = 0.5 ether;
        vm.deal(address(deCupNft), 1 ether);
        
        // Act
        vm.prank(USER);
        deCupNft.withdrawNative(withdrawAmount);
        
        // Assert
        assertEq(USER.balance, initialBalance + withdrawAmount);
        assertEq(address(deCupNft).balance, 0.5 ether);

    }

    function testWithdrawNativeZeroAmount() public {
        // Arrange
        vm.prank(USER);
        
        // Act / Assert
        vm.expectRevert(DeCupNft.DeCupNft__AmountMustBeGreaterThanZero.selector);
        deCupNft.withdrawNative(0);
    }


    function testWithdrawNativeInsufficientBalance() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(DeCupNft.DeCupNft__InsufficientBalance.selector);
        deCupNft.withdrawNative(1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                       ERC20 DEPOSIT / WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    function testReceiveERC20() public {
        // Arrange
        uint256 amount = 1000 * 10**18;
        
        // Act
        vm.startPrank(USER);
        mockToken.approve(address(deCupNft), amount);
        deCupNft.receiveERC20(address(mockToken), amount);
        vm.stopPrank();
        
        // Assert
        assertEq(mockToken.balanceOf(address(deCupNft)), amount);

    }

    function testWithdrawERC20() public {
        // Arrange
        uint256 initialBalance = mockToken.balanceOf(USER);
        uint256 withdrawAmount = 500 * 10**18;

        // Act
        vm.startPrank(USER);
        mockToken.transfer(address(deCupNft), 500 * 10**18);
        deCupNft.withdrawERC20(address(mockToken),withdrawAmount);
        vm.stopPrank();

        // Assert
        assertEq(mockToken.balanceOf(USER),initialBalance);
        assertEq(mockToken.balanceOf(address(deCupNft)), 0);

    }

    function testWithdrawERC20ZeroAmount() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(DeCupNft.DeCupNft__AmountMustBeGreaterThanZero.selector);
        deCupNft.withdrawERC20(address(mockToken), 0);
    }

    function testWithdrawERC20InsufficientBalance() public {
        // Arrange
        vm.prank(USER);

        // Act / Assert
        vm.expectRevert(DeCupNft.DeCupNft__InsufficientBalance.selector);
        deCupNft.withdrawERC20(address(mockToken), 1000 * 10**18);
    }

    function testReceiveERC20ZeroAmount() public {
        // Arrange
        vm.startPrank(USER);
        // Act / Assert
        mockToken.approve(address(deCupNft), 1000 * 10**18);
        vm.expectRevert(DeCupNft.DeCupNft__AmountMustBeGreaterThanZero.selector);
        deCupNft.receiveERC20(address(mockToken), 0);
        vm.stopPrank();
    }
}