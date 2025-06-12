// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DeCup} from "src/DeCup.sol";
import {DeployDeCup} from "script/DeployDeCup.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {FailingMockToken} from "../mocks/MockToken.sol";

contract DeCupTest is Test {
    DeCup public deCup;
    HelperConfig public config;
    address public mockToken;
    address public defaultWrapToken;
    HelperConfig.NetworkConfig public networkConfig;
    FailingMockToken public failingMockToken;
    address public USER = makeAddr("user");
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant INITIAL_ERC20_BALANCE = 1000e8;

    string public constant nativeDepositTokenURI =
        "data:application/json;base64,eyJuYW1lIjoiRGVDdXAiLCJkZXNjcmlwdGlvbiI6IkRlY2VudHJhbGl6ZWQgQ3VwIG9mIGFzc2V0cyIsICJhdHRyaWJ1dGVzIjogW3sidHJhaXRfdHlwZSI6IlRDTCIsInZhbHVlIjoiMCBVU0QifXsidHJhaXRfdHlwZSI6IkVUSCIsInZhbHVlIjoiMTAwMDAwMDAwMDAwMDAwMDAwMCJ9LF0sImltYWdlIjoiZGF0YTppbWFnZS9zdmcreG1sO2Jhc2U2NCxQSE4yWnlCM2FXUjBhRDBpTVRVMklpQm9aV2xuYUhROUlqRTFNQ0lnZG1sbGQwSnZlRDBpTUNBd0lERTFOaUF4TlRBaUlHWnBiR3c5SW01dmJtVWlJSGh0Ykc1elBTSm9kSFJ3T2k4dmQzZDNMbmN6TG05eVp5OHlNREF3TDNOMlp5SStDanh3WVhSb0lHUTlJazB4TWpFZ016QkRNVFl4SURZd0xqTXpNek1nTVRZeElEa3dMalkyTmpjZ01USXhJREV5TVNJZ2MzUnliMnRsUFNJak5ETTVRVVpGSWlCemRISnZhMlV0ZDJsa2RHZzlJakV3SWk4K0NqeHlaV04wSUhnOUlqazJJaUIzYVdSMGFEMGlNeklpSUdobGFXZG9kRDBpTVRVd0lpQm1hV3hzUFNJak5ETTVRVVpGSWk4K0NqeHlaV04wSUhnOUlqWTBJaUIzYVdSMGFEMGlNeklpSUdobGFXZG9kRDBpTVRVd0lpQm1hV3hzUFNJak5FVkJNVVpHSWk4K0NqeHlaV04wSUhnOUlqTXlJaUIzYVdSMGFEMGlNeklpSUdobGFXZG9kRDBpTVRVd0lpQm1hV3hzUFNJak5qTkJRMFpHSWk4K0NqeHlaV04wSUhkcFpIUm9QU0l6TWlJZ2FHVnBaMmgwUFNJeE5UQWlJR1pwYkd3OUlpTTNPVUk0UmtZaUx6NEtQR2NnWTJ4cGNDMXdZWFJvUFNKMWNtd29JMk5zYVhBd1h6UmZNakUwS1NJK0NqeHdZWFJvSUdROUlrMDJNeTQxSURFeU5pNDFNa000T0M0d056WTNJREV5Tmk0MU1pQXhNRGdnTVRBMkxqQXpNeUF4TURnZ09EQXVOelpETVRBNElEVTFMalE0TnpRZ09EZ3VNRGMyTnlBek5TQTJNeTQxSURNMVF6TTRMamt5TXpNZ016VWdNVGtnTlRVdU5EZzNOQ0F4T1NBNE1DNDNOa014T1NBeE1EWXVNRE16SURNNExqa3lNek1nTVRJMkxqVXlJRFl6TGpVZ01USTJMalV5V2lJZ2MzUnliMnRsUFNKM2FHbDBaU0lnYzNSeWIydGxMWGRwWkhSb1BTSXhNQ0l2UGdvOEwyYytDanhuSUdOc2FYQXRjR0YwYUQwaWRYSnNLQ05qYkdsd01WODBYekl4TkNraVBnbzhjR0YwYUNCa1BTSk5Oak11TlNBeE1qWXVOVEpET0RndU1EYzJOeUF4TWpZdU5USWdNVEE0SURFd05pNHdNek1nTVRBNElEZ3dMamMyUXpFd09DQTFOUzQwT0RjMElEZzRMakEzTmpjZ016VWdOak11TlNBek5VTXpPQzQ1TWpNeklETTFJREU1SURVMUxqUTROelFnTVRrZ09EQXVOelpETVRrZ01UQTJMakF6TXlBek9DNDVNak16SURFeU5pNDFNaUEyTXk0MUlERXlOaTQxTWxvaUlITjBjbTlyWlQwaUkwWTFSakJHTUNJZ2MzUnliMnRsTFhkcFpIUm9QU0l4TUNJdlBnbzhjR0YwYUNCa1BTSk5OVEVnTlRrdU1qWkROVEl1TmpVMk15QTFPUzR5TmlBMU15NDRNRGNnTlRrdU5qY3pOU0ExTkM0MU5EWTVJRFl3TGpReE16TkROVFV1TWpnMk5pQTJNUzR4TlRNeUlEVTFMamN3TURJZ05qSXVNekEwSURVMUxqY3dNRElnTmpNdU9UWXdNbFkyTnk0eE1qWXlRelUwTGpJME5qRWdOall1TkRNeE15QTFNaTQyTkRJeklEWTJMakExT1RnZ05URWdOall1TURVNU9FTTBPQzR4TURreklEWTJMakExT1RnZ05EVXVNek0zTVNBMk55NHlNRGd6SURRekxqSTVNeUEyT1M0eU5USXlRelF4TGpJME9EZ2dOekV1TWprMk15QTBNQzR3T1RrMklEYzBMakEyT1RNZ05EQXVNRGs1TmlBM05pNDVOakF5UXpRd0xqQTVPVGNnTnprdU9EVXhJRFF4TGpJME9Ea2dPREl1TmpJek1TQTBNeTR5T1RNZ09EUXVOalkzTWtNME5TNHpNemN4SURnMkxqY3hNVE1nTkRndU1UQTVNaUE0Tnk0NE5UazJJRFV4SURnM0xqZzFPVFpETlRJdU5qUXlOU0E0Tnk0NE5UazJJRFUwTGpJME5pQTROeTQwT0RjMElEVTFMamN3TURJZ09EWXVOemt5TWxZNE9TNDVOakF5UXpVMUxqY3dNRElnT1RFdU5qRTJNU0ExTlM0eU9EWTBJRGt5TGpjMk5qTWdOVFF1TlRRMk9TQTVNeTQxTURZeFF6VXpMamd3TnlBNU5DNHlORFU1SURVeUxqWTFOak1nT1RRdU5qWXdOQ0ExTVNBNU5DNDJOakEwU0RNNExqVldOVGt1TWpaSU5URmFUVFUyTGpjd01ESWdOamd1T0RZNE5FTTFOeTR4TmpBMUlEWTVMakU1TWpZZ05UY3VOVGsyTlNBMk9TNDFOVFU0SURVNElEWTVMamsxT1RKRE5Ua3VPRFUyTmlBM01TNDRNVFU0SURZd0xqa3dNRFFnTnpRdU16TTBOaUEyTUM0NU1EQTBJRGMyTGprMk1ESkROakF1T1RBd015QTNPUzQxT0RVNElEVTVMamcxTmpZZ09ESXVNVEF6TmlBMU9DQTRNeTQ1TmpBeVF6VTNMalU1TmpZZ09EUXVNell6TlNBMU55NHhOakF6SURnMExqY3lOVGtnTlRZdU56QXdNaUE0TlM0d05WWTJPQzQ0TmpnMFdrMDBNUzR3T1RrMklEYzJMamsyTURKRE5ERXVNRGs1TmlBM05DNHpNelEySURReUxqRTBNelFnTnpFdU9ERTFPQ0EwTkNBMk9TNDVOVGt5UXpRMUxqZzFOallnTmpndU1UQXlPU0EwT0M0ek56UTFJRFkzTGpBMU9UZ2dOVEVnTmpjdU1EVTVPRU0xTWk0Mk5UVTVJRFkzTGpBMU9UZ2dOVFF1TWpZNE9DQTJOeTQwTnpVeUlEVTFMamN3TURJZ05qZ3VNalEzTTFZNE5TNDJOekV4UXpVMExqSTJPRFlnT0RZdU5EUXpOU0ExTWk0Mk5UWXhJRGcyTGpnMU9UWWdOVEVnT0RZdU9EVTVOa00wT0M0ek56UTBJRGcyTGpnMU9UWWdORFV1T0RVMk5pQTROUzQ0TVRZNElEUTBJRGd6TGprMk1ESkROREl1TVRRek5DQTRNaTR4TURNMklEUXhMakE1T1RjZ056a3VOVGcxT0NBME1TNHdPVGsySURjMkxqazJNREphSWlCbWFXeHNQU0lqUmpWR01FWXdJaUJ6ZEhKdmEyVTlJaU5HTlVZd1JqQWlMejRLUEhCaGRHZ2daRDBpVFRVM0xqYzJNRFFnTVRBd0xqZzJTRGN3TGpJek9UaEROekV1TVRBd05DQXhNREF1T0RZZ056SXVNREl4SURFd01TNHlPRGdnTnpNdU1EQTJOQ0F4TURJdU1qY3pURGM0TGpNNU16SWdNVEEzTGpZMlNEUTVMall3TjB3MU5DNDVPVE00SURFd01pNHlOek5ETlRVdU9URTNOeUF4TURFdU16UTVJRFUyTGpjNE5EUWdNVEF3TGpreE5TQTFOeTQxT1RneUlERXdNQzQ0TmpWTU5UY3VOell3TkNBeE1EQXVPRFphSWlCbWFXeHNQU0lqUmpWR01FWXdJaUJ6ZEhKdmEyVTlJaU5HTlVZd1JqQWlMejRLUEM5blBnbzhaeUJqYkdsd0xYQmhkR2c5SW5WeWJDZ2pZMnhwY0RKZk5GOHlNVFFwSWo0S1BIQmhkR2dnWkQwaVRUWTFMalVnTVRJMkxqVXlRemt3TGpBM05qY2dNVEkyTGpVeUlERXhNQ0F4TURZdU1ETXpJREV4TUNBNE1DNDNOa014TVRBZ05UVXVORGczTkNBNU1DNHdOelkzSURNMUlEWTFMalVnTXpWRE5EQXVPVEl6TXlBek5TQXlNU0ExTlM0ME9EYzBJREl4SURnd0xqYzJRekl4SURFd05pNHdNek1nTkRBdU9USXpNeUF4TWpZdU5USWdOalV1TlNBeE1qWXVOVEphSWlCemRISnZhMlU5SWlORlFrVkJSVUVpSUhOMGNtOXJaUzEzYVdSMGFEMGlNVEFpTHo0S1BIQmhkR2dnWkQwaVRUWTRMallnTlRndU56WkROelV1TlRNek15QTFPQzQzTmlBNE1DNDNNek16SURZeExqTTJJRGcwTGpJZ05qWXVOVFpET0RjdU5qWTJOeUEzTVM0M05pQTRPUzQwSURjMkxqazJJRGc1TGpRZ09ESXVNVFpET0RVdU9UTXpNeUE1TUM0NE1qWTNJRGM1TGpnMk5qY2dPVFV1TVRZZ056RXVNaUE1TlM0eE5rZzJObFk0Tnk0ek5rZzNNUzR5UXpjMExqWTJOamNnT0RjdU16WWdOemN1TWpZMk55QTROUzQyTWpZM0lEYzVJRGd5TGpFMlF6YzNMakkyTmpjZ056Z3VOamt6TXlBM05DNDJOalkzSURjMkxqazJJRGN4TGpJZ056WXVPVFpJTmpaV05UZ3VOelpJTmpndU5sb2lJR1pwYkd3OUlpTkZRa1ZCUlVFaUx6NEtQSEJoZEdnZ1pEMGlUVFU1TGpjMklERXdNQzR6TmtnM01pNHlORU0zTXk0eU9DQXhNREF1TXpZZ056UXVNeklnTVRBd0xqZzRJRGMxTGpNMklERXdNUzQ1TWt3NE1TNDJJREV3T0M0eE5rZzFNQzQwVERVMkxqWTBJREV3TVM0NU1rTTFOeTQyT0NBeE1EQXVPRGdnTlRndU56SWdNVEF3TGpNMklEVTVMamMySURFd01DNHpObG9pSUdacGJHdzlJaU5GUWtWQlJVRWlMejRLUEM5blBnbzhaeUJqYkdsd0xYQmhkR2c5SW5WeWJDZ2pZMnhwY0ROZk5GOHlNVFFwSWo0S1BIQmhkR2dnWkQwaVRUWTFMalVnTVRJMkxqVXlRemt3TGpBM05qY2dNVEkyTGpVeUlERXhNQ0F4TURZdU1ETXpJREV4TUNBNE1DNDNOa014TVRBZ05UVXVORGczTkNBNU1DNHdOelkzSURNMUlEWTFMalVnTXpWRE5EQXVPVEl6TXlBek5TQXlNU0ExTlM0ME9EYzBJREl4SURnd0xqYzJRekl4SURFd05pNHdNek1nTkRBdU9USXpNeUF4TWpZdU5USWdOalV1TlNBeE1qWXVOVEphSWlCemRISnZhMlU5SWlORk1FUkdSRVlpSUhOMGNtOXJaUzEzYVdSMGFEMGlNVEFpTHo0S1BDOW5QZ284WkdWbWN6NEtQR05zYVhCUVlYUm9JR2xrUFNKamJHbHdNRjgwWHpJeE5DSStDanh5WldOMElIZHBaSFJvUFNJek1pSWdhR1ZwWjJoMFBTSXhNamdpSUdacGJHdzlJbmRvYVhSbElpQjBjbUZ1YzJadmNtMDlJblJ5WVc1emJHRjBaU2d3SURFM0tTSXZQZ284TDJOc2FYQlFZWFJvUGdvOFkyeHBjRkJoZEdnZ2FXUTlJbU5zYVhBeFh6UmZNakUwSWo0S1BISmxZM1FnZDJsa2RHZzlJak15SWlCb1pXbG5hSFE5SWpFeU9DSWdabWxzYkQwaWQyaHBkR1VpSUhSeVlXNXpabTl5YlQwaWRISmhibk5zWVhSbEtETXlJREUzS1NJdlBnbzhMMk5zYVhCUVlYUm9QZ284WTJ4cGNGQmhkR2dnYVdROUltTnNhWEF5WHpSZk1qRTBJajRLUEhKbFkzUWdkMmxrZEdnOUlqTXlJaUJvWldsbmFIUTlJakV5T0NJZ1ptbHNiRDBpZDJocGRHVWlJSFJ5WVc1elptOXliVDBpZEhKaGJuTnNZWFJsS0RZMElERTNLU0l2UGdvOEwyTnNhWEJRWVhSb1BnbzhZMnhwY0ZCaGRHZ2dhV1E5SW1Oc2FYQXpYelJmTWpFMElqNEtQSEpsWTNRZ2QybGtkR2c5SWpNeUlpQm9aV2xuYUhROUlqRXlPQ0lnWm1sc2JEMGlkMmhwZEdVaUlIUnlZVzV6Wm05eWJUMGlkSEpoYm5Oc1lYUmxLRGsySURFM0tTSXZQZ284TDJOc2FYQlFZWFJvUGdvOEwyUmxabk0rQ2p3dmMzWm5QZ289In0=";

    function setUp() external {
        DeployDeCup deployer = new DeployDeCup();

        (deCup, config) = deployer.run();
        failingMockToken = new FailingMockToken(1000 ether);
        networkConfig = config.getConfig();
        mockToken = networkConfig.tokenAddresses[0];
        defaultWrapToken = networkConfig.defaultPriceFeed;
        // Fund the user
        vm.deal(USER, INITIAL_BALANCE);
        console.log(msg.sender);
        console.log(IERC20(mockToken).balanceOf(address(deployer)));
        vm.prank(address(deployer));
        IERC20(mockToken).transfer(USER, INITIAL_ERC20_BALANCE);
        failingMockToken.transfer(USER, INITIAL_ERC20_BALANCE);
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
        new DeCup(svgDeCup, tokenAddresses, priceFeedAddresses, defaultWrapToken);
    }

    function testDeployZeroPriceFeedAddresses() public {
        string memory svgDeCup = vm.readFile("./img/decup.svg");
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses;
        tokenAddresses[0] = address(mockToken);
        vm.expectRevert(DeCup.DeCup__PriceFeedAddressesMustNotBeEmpty.selector);
        new DeCup(svgDeCup, tokenAddresses, priceFeedAddresses, defaultWrapToken);
    }

    function testDeployTokenAddressesLengthNotToEqualPriceFeedAddressesLength() public {
        string memory svgDeCup = vm.readFile("./img/decup.svg");
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](2);
        tokenAddresses[0] = address(mockToken);
        priceFeedAddresses[0] = address(0x1); // Mock price feed address for testing
        priceFeedAddresses[1] = address(0x2); // Mock price feed address for testing
        vm.expectRevert(DeCup.DeCup__TokenAddressesAndPriceFeedAddressesMusBeSameLength.selector);
        new DeCup(svgDeCup, tokenAddresses, priceFeedAddresses, defaultWrapToken);
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

    function testDepositedNativeCurrencyMintedTokenURI() public {
        // Arrange
        uint256 amount = 1 ether;

        // Act
        vm.prank(USER);
        (bool success,) = address(deCup).call{value: amount}("");
        // Assert
        assert(success);
        assertEq(deCup.tokenURI(0), nativeDepositTokenURI);
    }

    /*//////////////////////////////////////////////////////////////
                       ERC20 DEPOSIT / WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    function testDepositeSingleTokenWithNotAllowedToken() public {
        // Arrange
        vm.startPrank(USER);
        uint256 amount = 1000 * 10 ** 8;
        MockToken notAllowedToken = new MockToken("WETH", "WETH", USER, amount);

        // Act
        notAllowedToken.approve(address(deCup), amount);
        vm.expectRevert(DeCup.DeCup__NotAllowedToken.selector);
        deCup.depositeSingleTokenAndMint(address(notAllowedToken), amount);
        vm.stopPrank();
    }

    function testDepositeSingleToken() public {
        // Arrange
        uint256 initialBalance = IERC20(mockToken).balanceOf(USER);
        uint256 depositAmount = 500 * 10 ** 8;

        // Act - First deposit to mint NFT, then burn to withdraw
        vm.startPrank(USER);
        IERC20(mockToken).approve(address(deCup), depositAmount);
        deCup.depositeSingleTokenAndMint(address(mockToken), depositAmount);

        uint256 tokenId = 0; // First minted token will have ID 0
        deCup.burn(tokenId); // Burn NFT to withdraw collateral
        vm.stopPrank();

        // Assert
        assertEq(IERC20(mockToken).balanceOf(USER), initialBalance);
        assertEq(IERC20(mockToken).balanceOf(address(deCup)), 0);
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
        IERC20(mockToken).approve(address(deCup), 1000 * 10 ** 18);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        deCup.depositeSingleTokenAndMint(address(mockToken), 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE ASSETS DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function testDepositeMultipleAssetsAndMintSuccess() public {
        // Arrange
        uint256 initialMockTokenBalance = IERC20(mockToken).balanceOf(USER);
        uint256 initialFailingTokenBalance = failingMockToken.balanceOf(USER);
        uint256 initialEthBalance = USER.balance;

        uint256 mockTokenAmount = 500 * 10 ** 8;
        uint256 failingTokenAmount = 300 * 10 ** 8;
        uint256 ethAmount = 1 ether;

        address[] memory tokenAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokenAddresses[0] = address(mockToken);
        tokenAddresses[1] = address(failingMockToken);
        amounts[0] = mockTokenAmount;
        amounts[1] = failingTokenAmount;

        // Act
        vm.startPrank(USER);
        IERC20(mockToken).approve(address(deCup), mockTokenAmount);
        failingMockToken.approve(address(deCup), failingTokenAmount);
        deCup.depositeMultipleAssetsAndMint{value: ethAmount}(tokenAddresses, amounts);

        uint256 tokenId = 0; // First minted token will have ID 0
        deCup.burn(tokenId); // Burn NFT to withdraw all collateral
        vm.stopPrank();

        // Assert
        assertEq(IERC20(mockToken).balanceOf(USER), initialMockTokenBalance);
        assertEq(IERC20(failingMockToken).balanceOf(USER), initialFailingTokenBalance);
        assertEq(USER.balance, initialEthBalance);
        assertEq(IERC20(mockToken).balanceOf(address(deCup)), 0);
        assertEq(failingMockToken.balanceOf(address(deCup)), 0);
        assertEq(address(deCup).balance, 0);
    }

    function testDepositeMultipleAssetsAndMintWithoutNativeCurrency() public {
        // Arrange
        uint256 initialMockTokenBalance = IERC20(mockToken).balanceOf(USER);
        uint256 initialFailingTokenBalance = failingMockToken.balanceOf(USER);

        uint256 mockTokenAmount = 500 * 10 ** 8;
        uint256 failingTokenAmount = 300 * 10 ** 8;

        address[] memory tokenAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokenAddresses[0] = address(mockToken);
        tokenAddresses[1] = address(failingMockToken);
        amounts[0] = mockTokenAmount;
        amounts[1] = failingTokenAmount;

        // Act
        vm.startPrank(USER);
        IERC20(mockToken).approve(address(deCup), mockTokenAmount);
        failingMockToken.approve(address(deCup), failingTokenAmount);
        deCup.depositeMultipleAssetsAndMint(tokenAddresses, amounts);

        uint256 tokenId = 0; // First minted token will have ID 0
        deCup.burn(tokenId); // Burn NFT to withdraw all collateral
        vm.stopPrank();

        // Assert
        assertEq(IERC20(mockToken).balanceOf(USER), initialMockTokenBalance);
        assertEq(failingMockToken.balanceOf(USER), initialFailingTokenBalance);
        assertEq(IERC20(mockToken).balanceOf(address(deCup)), 0);
        assertEq(failingMockToken.balanceOf(address(deCup)), 0);
    }

    function testDepositeMultipleAssetsAndMintSingleToken() public {
        // Arrange
        uint256 initialMockTokenBalance = IERC20(mockToken).balanceOf(USER);
        uint256 mockTokenAmount = 500 * 10 ** 8;

        address[] memory tokenAddresses = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenAddresses[0] = address(mockToken);
        amounts[0] = mockTokenAmount;

        // Act
        vm.startPrank(USER);
        IERC20(mockToken).approve(address(deCup), mockTokenAmount);
        deCup.depositeMultipleAssetsAndMint(tokenAddresses, amounts);

        uint256 tokenId = 0; // First minted token will have ID 0
        deCup.burn(tokenId); // Burn NFT to withdraw collateral
        vm.stopPrank();

        // Assert
        assertEq(IERC20(mockToken).balanceOf(USER), initialMockTokenBalance);
        assertEq(IERC20(mockToken).balanceOf(address(deCup)), 0);
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
        amounts[0] = 500 * 10 ** 8;
        amounts[1] = 0; // Zero amount should fail

        // Act / Assert
        vm.startPrank(USER);
        IERC20(mockToken).approve(address(deCup), amounts[0]);
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
