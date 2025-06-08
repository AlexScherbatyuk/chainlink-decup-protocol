// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DeCup} from "src/DeCup.sol";
import {DeployDeCup} from "script/DeployDeCup.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {FailingMockToken} from "../mocks/MockToken.sol";

contract DeCupTest is Test {
    DeCup public deCup;
    MockToken public mockToken;
    FailingMockToken public failingMockToken;
    address public USER = makeAddr("user");
    uint256 public constant INITIAL_BALANCE = 1000 ether;

    function setUp() external {
        string memory svgDeCup = vm.readFile("./img/decup.svg");
        mockToken = new MockToken(1000 ether);
        failingMockToken = new FailingMockToken(1000 ether);

        // Deploy contract with MockToken as allowed token
        address[] memory tokenAddresses = new address[](2);
        address[] memory priceFeedAddresses = new address[](2);
        tokenAddresses[0] = address(mockToken);
        tokenAddresses[1] = address(failingMockToken);
        priceFeedAddresses[0] = address(0x1); // Mock price feed address for testing
        priceFeedAddresses[1] = address(0x2); // Mock price feed address for testing

        deCup = new DeCup(svgDeCup, tokenAddresses, priceFeedAddresses);

        // Fund the user
        vm.deal(USER, INITIAL_BALANCE);
        mockToken.transfer(USER, INITIAL_BALANCE);
        failingMockToken.transfer(USER, INITIAL_BALANCE);
    }
    /*//////////////////////////////////////////////////////////////
                              TEST DEPLOY
    //////////////////////////////////////////////////////////////*/

    function testDeployZeroTokenAddresses() public {
        string memory svgDeCup = vm.readFile("./img/decup.svg");
        address[] memory tokenAddresses;
        address[] memory priceFeedAddresses = new address[](1);
        priceFeedAddresses[0] = address(0x1);
        vm.expectRevert(DeCup.DeCup__AllowedTokenAddressesMustNotBeEmpty.selector);
        new DeCup(svgDeCup, tokenAddresses, priceFeedAddresses);
    }

    function testDeployZeroPriceFeedAddresses() public {
        string memory svgDeCup = vm.readFile("./img/decup.svg");
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses;
        tokenAddresses[0] = address(mockToken);
        vm.expectRevert(DeCup.DeCup__PriceFeedAddressesMustNotBeEmpty.selector);
        new DeCup(svgDeCup, tokenAddresses, priceFeedAddresses);
    }

    function testDeployTokenAddressesLengthNotToEqualPriceFeedAddressesLength() public {
        string memory svgDeCup = vm.readFile("./img/decup.svg");
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](2);
        tokenAddresses[0] = address(mockToken);
        priceFeedAddresses[0] = address(0x1); // Mock price feed address for testing
        priceFeedAddresses[1] = address(0x2); // Mock price feed address for testing
        vm.expectRevert(DeCup.DeCup__TokenAddressesAndPriceFeedAddressesMusBeSameLength.selector);
        new DeCup(svgDeCup, tokenAddresses, priceFeedAddresses);
    }

    /*//////////////////////////////////////////////////////////////
                  NATIVE CURRENCY DEPOSIT / WITHDRAWAL
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
    function testWithdrawNativeCurrency() public {
        // Arrange
        uint256 initialBalance = USER.balance;

        // First deposit 1 ether to get an NFT
        vm.prank(USER);
        (bool success,) = address(deCup).call{value: 1 ether}("");
        assert(success);

        uint256 tokenId = 0; // First minted token will have ID 0

        // Act - Burn the NFT to withdraw the collateral
        vm.prank(USER);
        deCup.burn(tokenId);

        // Assert
        assertEq(USER.balance, initialBalance); // User should get back their 1 ether
        assertEq(address(deCup).balance, 0); // Contract should have no balance
    }

    /*//////////////////////////////////////////////////////////////
                       ERC20 DEPOSIT / WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    function testDepositeSingleTokenWithNotAllowedToken() public {
        // Arrange
        vm.startPrank(USER);
        uint256 amount = 1000 * 10 ** 18;
        MockToken notAllowedToken = new MockToken(1000 ether);

        // Act
        notAllowedToken.approve(address(deCup), amount);
        vm.expectRevert(DeCup.DeCup__NotAllowedToken.selector);
        deCup.depositeSingleTokenAndMint(address(notAllowedToken), amount);
        vm.stopPrank();
    }

    function testDepositeSingleToken() public {
        // Arrange
        uint256 initialBalance = mockToken.balanceOf(USER);
        uint256 depositAmount = 500 * 10 ** 18;

        // Act - First deposit to mint NFT, then burn to withdraw
        vm.startPrank(USER);
        mockToken.approve(address(deCup), depositAmount);
        deCup.depositeSingleTokenAndMint(address(mockToken), depositAmount);

        uint256 tokenId = 0; // First minted token will have ID 0
        deCup.burn(tokenId); // Burn NFT to withdraw collateral
        vm.stopPrank();

        // Assert
        assertEq(mockToken.balanceOf(USER), initialBalance);
        assertEq(mockToken.balanceOf(address(deCup)), 0);
    }

    function testWithdrawNonExistingNft() public {
        // This test doesn't apply to the current architecture since withdrawal
        // is done through burn() which withdraws the exact collateral amount
        // We can test that burning a non-existent token fails instead
        vm.prank(USER);
        vm.expectRevert(DeCup.DeCup__TokenDoesNotExist.selector);
        deCup.burn(999); // Try to burn non-existent token
    }

    function testDepositeERC20ZeroAmount() public {
        // Arrange
        vm.startPrank(USER);
        // Act / Assert
        mockToken.approve(address(deCup), 1000 * 10 ** 18);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        deCup.depositeSingleTokenAndMint(address(mockToken), 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE ASSETS DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function testDepositeMultipleAssetsAndMintSuccess() public {
        // Arrange
        uint256 initialMockTokenBalance = mockToken.balanceOf(USER);
        uint256 initialFailingTokenBalance = failingMockToken.balanceOf(USER);
        uint256 initialEthBalance = USER.balance;

        uint256 mockTokenAmount = 500 * 10 ** 18;
        uint256 failingTokenAmount = 300 * 10 ** 18;
        uint256 ethAmount = 1 ether;

        address[] memory tokenAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokenAddresses[0] = address(mockToken);
        tokenAddresses[1] = address(failingMockToken);
        amounts[0] = mockTokenAmount;
        amounts[1] = failingTokenAmount;

        // Act
        vm.startPrank(USER);
        mockToken.approve(address(deCup), mockTokenAmount);
        failingMockToken.approve(address(deCup), failingTokenAmount);
        deCup.depositeMultipleAssetsAndMint{value: ethAmount}(tokenAddresses, amounts);

        uint256 tokenId = 0; // First minted token will have ID 0
        deCup.burn(tokenId); // Burn NFT to withdraw all collateral
        vm.stopPrank();

        // Assert
        assertEq(mockToken.balanceOf(USER), initialMockTokenBalance);
        assertEq(failingMockToken.balanceOf(USER), initialFailingTokenBalance);
        assertEq(USER.balance, initialEthBalance);
        assertEq(mockToken.balanceOf(address(deCup)), 0);
        assertEq(failingMockToken.balanceOf(address(deCup)), 0);
        assertEq(address(deCup).balance, 0);
    }

    function testDepositeMultipleAssetsAndMintWithoutNativeCurrency() public {
        // Arrange
        uint256 initialMockTokenBalance = mockToken.balanceOf(USER);
        uint256 initialFailingTokenBalance = failingMockToken.balanceOf(USER);

        uint256 mockTokenAmount = 500 * 10 ** 18;
        uint256 failingTokenAmount = 300 * 10 ** 18;

        address[] memory tokenAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokenAddresses[0] = address(mockToken);
        tokenAddresses[1] = address(failingMockToken);
        amounts[0] = mockTokenAmount;
        amounts[1] = failingTokenAmount;

        // Act
        vm.startPrank(USER);
        mockToken.approve(address(deCup), mockTokenAmount);
        failingMockToken.approve(address(deCup), failingTokenAmount);
        deCup.depositeMultipleAssetsAndMint(tokenAddresses, amounts);

        uint256 tokenId = 0; // First minted token will have ID 0
        deCup.burn(tokenId); // Burn NFT to withdraw all collateral
        vm.stopPrank();

        // Assert
        assertEq(mockToken.balanceOf(USER), initialMockTokenBalance);
        assertEq(failingMockToken.balanceOf(USER), initialFailingTokenBalance);
        assertEq(mockToken.balanceOf(address(deCup)), 0);
        assertEq(failingMockToken.balanceOf(address(deCup)), 0);
    }

    function testDepositeMultipleAssetsAndMintSingleToken() public {
        // Arrange
        uint256 initialMockTokenBalance = mockToken.balanceOf(USER);
        uint256 mockTokenAmount = 500 * 10 ** 18;

        address[] memory tokenAddresses = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenAddresses[0] = address(mockToken);
        amounts[0] = mockTokenAmount;

        // Act
        vm.startPrank(USER);
        mockToken.approve(address(deCup), mockTokenAmount);
        deCup.depositeMultipleAssetsAndMint(tokenAddresses, amounts);

        uint256 tokenId = 0; // First minted token will have ID 0
        deCup.burn(tokenId); // Burn NFT to withdraw collateral
        vm.stopPrank();

        // Assert
        assertEq(mockToken.balanceOf(USER), initialMockTokenBalance);
        assertEq(mockToken.balanceOf(address(deCup)), 0);
    }

    function testDepositeMultipleAssetsAndMintArrayLengthMismatch() public {
        // Arrange
        address[] memory tokenAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](1); // Different length
        tokenAddresses[0] = address(mockToken);
        tokenAddresses[1] = address(failingMockToken);
        amounts[0] = 500 * 10 ** 18;

        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(DeCup.DeCup__TokenAddressesAndAmountsMusBeSameLength.selector);
        deCup.depositeMultipleAssetsAndMint(tokenAddresses, amounts);
    }

    function testDepositeMultipleAssetsAndMintZeroAmount() public {
        // Arrange
        address[] memory tokenAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokenAddresses[0] = address(mockToken);
        tokenAddresses[1] = address(failingMockToken);
        amounts[0] = 500 * 10 ** 18;
        amounts[1] = 0; // Zero amount should fail

        // Act / Assert
        vm.startPrank(USER);
        mockToken.approve(address(deCup), amounts[0]);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        deCup.depositeMultipleAssetsAndMint(tokenAddresses, amounts);
        vm.stopPrank();
    }

    function testDepositeMultipleAssetsAndMintTransferFailed() public {
        // Arrange - Set failing token to fail transfers
        address[] memory tokenAddresses = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenAddresses[0] = address(failingMockToken);
        amounts[0] = 500 * 10 ** 18;

        // Act / Assert
        vm.startPrank(USER);
        failingMockToken.approve(address(deCup), amounts[0]);
        failingMockToken.setShouldFailTransfer(true); // Make the transfer return false
        vm.expectRevert(DeCup.DeCup__TransferFailed.selector);
        deCup.depositeMultipleAssetsAndMint(tokenAddresses, amounts);
        vm.stopPrank();
    }

    function testDepositeMultipleAssetsAndMintEmptyArrays() public {
        // Arrange
        address[] memory tokenAddresses = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        uint256 ethAmount = 1 ether;

        // Act - Should succeed with only native currency
        vm.startPrank(USER);
        deCup.depositeMultipleAssetsAndMint{value: ethAmount}(tokenAddresses, amounts);

        uint256 tokenId = 0;
        deCup.burn(tokenId);
        vm.stopPrank();

        // Assert - User should get back their ETH
        assertEq(USER.balance, INITIAL_BALANCE);
        assertEq(address(deCup).balance, 0);
    }

    function testDepositeMultipleAssetsAndMintEmptyArraysNoValue() public {
        // Arrange
        address[] memory tokenAddresses = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        // Act - Should succeed but mint an NFT with no collateral
        vm.prank(USER);
        deCup.depositeMultipleAssetsAndMint(tokenAddresses, amounts);

        // Assert - NFT should be minted
        assertEq(deCup.balanceOf(USER), 1);
        assertEq(deCup.ownerOf(0), USER);
    }
}
