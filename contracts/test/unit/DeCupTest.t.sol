// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DeCup} from "src/DeCup.sol";
import {DeployDeCup} from "script/DeployDeCup.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {FailingMockToken} from "../mocks/MockToken.sol";

contract DeCupTest is Test {
    DeCup public s_deCup;
    HelperConfig public s_config;
    HelperConfig.NetworkConfig public s_networkConfig;
    FailingMockToken public s_failingMockToken;

    string public s_svgDeCupImage;

    address public s_mockTokenWeth;
    address public s_mockTokenWbtc;
    address public s_mockTokenUsdc;
    address public s_defaultWrapToken;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_BALANCE_ETH = 1000 ether;
    uint256 public constant INITIAL_ERC20_WETH = 1000e18;
    uint256 public constant INITIAL_ERC20_WBTC = 1000e8;
    uint256 public constant INITIAL_ERC20_USDC = 1000e6;

    string public constant s_nativeDepositTokenURI =
        "data:application/json;base64,eyJ0b2tlbklkIjoiMCIsIm5hbWUiOiJEZUN1cCMwICQxNTUwMDAiLCJkZXNjcmlwdGlvbiI6IkRlY2VudHJhbGl6ZWQgQ3VwIG9mIGFzc2V0cyIsICJhdHRyaWJ1dGVzIjogW3sidHJhaXRfdHlwZSI6IlRDTCIsInZhbHVlIjoiMTU1MDAwIFVTRCJ9LHsidHJhaXRfdHlwZSI6IkVUSCIsInZhbHVlIjoiMTAwMDAwMDAwMDAwMDAwMDAwMCJ9LHsidHJhaXRfdHlwZSI6IldFVEgiLCJ2YWx1ZSI6IjE1MDAwMDAwMDAwMDAwMDAwMDAifSx7InRyYWl0X3R5cGUiOiJXQlRDIiwidmFsdWUiOiIxMDAwMDAwMDAwMCJ9LHsidHJhaXRfdHlwZSI6IlVTREMiLCJ2YWx1ZSI6IjUwMDAwMDAwIn1dLCJpbWFnZSI6ImRhdGE6aW1hZ2Uvc3ZnK3htbDtiYXNlNjQsUEhOMlp5QjNhV1IwYUQwaU1UVTJJaUJvWldsbmFIUTlJakUxTUNJZ2RtbGxkMEp2ZUQwaU1DQXdJREUxTmlBeE5UQWlJR1pwYkd3OUltNXZibVVpSUhodGJHNXpQU0pvZEhSd09pOHZkM2QzTG5jekxtOXlaeTh5TURBd0wzTjJaeUkrQ2p4d1lYUm9JR1E5SWsweE1qRWdNekJETVRZeElEWXdMak16TXpNZ01UWXhJRGt3TGpZMk5qY2dNVEl4SURFeU1TSWdjM1J5YjJ0bFBTSWpORE01UVVaRklpQnpkSEp2YTJVdGQybGtkR2c5SWpFd0lpOCtDanh5WldOMElIZzlJamsySWlCM2FXUjBhRDBpTXpJaUlHaGxhV2RvZEQwaU1UVXdJaUJtYVd4c1BTSWpORE01UVVaRklpOCtDanh5WldOMElIZzlJalkwSWlCM2FXUjBhRDBpTXpJaUlHaGxhV2RvZEQwaU1UVXdJaUJtYVd4c1BTSWpORVZCTVVaR0lpOCtDanh5WldOMElIZzlJak15SWlCM2FXUjBhRDBpTXpJaUlHaGxhV2RvZEQwaU1UVXdJaUJtYVd4c1BTSWpOak5CUTBaR0lpOCtDanh5WldOMElIZHBaSFJvUFNJek1pSWdhR1ZwWjJoMFBTSXhOVEFpSUdacGJHdzlJaU0zT1VJNFJrWWlMejRLUEdjZ1kyeHBjQzF3WVhSb1BTSjFjbXdvSTJOc2FYQXdYelJmTWpFMEtTSStDanh3WVhSb0lHUTlJazAyTXk0MUlERXlOaTQxTWtNNE9DNHdOelkzSURFeU5pNDFNaUF4TURnZ01UQTJMakF6TXlBeE1EZ2dPREF1TnpaRE1UQTRJRFUxTGpRNE56UWdPRGd1TURjMk55QXpOU0EyTXk0MUlETTFRek00TGpreU16TWdNelVnTVRrZ05UVXVORGczTkNBeE9TQTRNQzQzTmtNeE9TQXhNRFl1TURNeklETTRMamt5TXpNZ01USTJMalV5SURZekxqVWdNVEkyTGpVeVdpSWdjM1J5YjJ0bFBTSjNhR2wwWlNJZ2MzUnliMnRsTFhkcFpIUm9QU0l4TUNJdlBnbzhMMmMrQ2p4bklHTnNhWEF0Y0dGMGFEMGlkWEpzS0NOamJHbHdNVjgwWHpJeE5Da2lQZ284Y0dGMGFDQmtQU0pOTmpNdU5TQXhNall1TlRKRE9EZ3VNRGMyTnlBeE1qWXVOVElnTVRBNElERXdOaTR3TXpNZ01UQTRJRGd3TGpjMlF6RXdPQ0ExTlM0ME9EYzBJRGc0TGpBM05qY2dNelVnTmpNdU5TQXpOVU16T0M0NU1qTXpJRE0xSURFNUlEVTFMalE0TnpRZ01Ua2dPREF1TnpaRE1Ua2dNVEEyTGpBek15QXpPQzQ1TWpNeklERXlOaTQxTWlBMk15NDFJREV5Tmk0MU1sb2lJSE4wY205clpUMGlJMFkxUmpCR01DSWdjM1J5YjJ0bExYZHBaSFJvUFNJeE1DSXZQZ284Y0dGMGFDQmtQU0pOTlRFZ05Ua3VNalpETlRJdU5qVTJNeUExT1M0eU5pQTFNeTQ0TURjZ05Ua3VOamN6TlNBMU5DNDFORFk1SURZd0xqUXhNek5ETlRVdU1qZzJOaUEyTVM0eE5UTXlJRFUxTGpjd01ESWdOakl1TXpBMElEVTFMamN3TURJZ05qTXVPVFl3TWxZMk55NHhNall5UXpVMExqSTBOakVnTmpZdU5ETXhNeUExTWk0Mk5ESXpJRFkyTGpBMU9UZ2dOVEVnTmpZdU1EVTVPRU0wT0M0eE1Ea3pJRFkyTGpBMU9UZ2dORFV1TXpNM01TQTJOeTR5TURneklEUXpMakk1TXlBMk9TNHlOVEl5UXpReExqSTBPRGdnTnpFdU1qazJNeUEwTUM0d09UazJJRGMwTGpBMk9UTWdOREF1TURrNU5pQTNOaTQ1TmpBeVF6UXdMakE1T1RjZ056a3VPRFV4SURReExqSTBPRGtnT0RJdU5qSXpNU0EwTXk0eU9UTWdPRFF1TmpZM01rTTBOUzR6TXpjeElEZzJMamN4TVRNZ05EZ3VNVEE1TWlBNE55NDROVGsySURVeElEZzNMamcxT1RaRE5USXVOalF5TlNBNE55NDROVGsySURVMExqSTBOaUE0Tnk0ME9EYzBJRFUxTGpjd01ESWdPRFl1TnpreU1sWTRPUzQ1TmpBeVF6VTFMamN3TURJZ09URXVOakUyTVNBMU5TNHlPRFkwSURreUxqYzJOak1nTlRRdU5UUTJPU0E1TXk0MU1EWXhRelV6TGpnd055QTVOQzR5TkRVNUlEVXlMalkxTmpNZ09UUXVOall3TkNBMU1TQTVOQzQyTmpBMFNETTRMalZXTlRrdU1qWklOVEZhVFRVMkxqY3dNRElnTmpndU9EWTRORU0xTnk0eE5qQTFJRFk1TGpFNU1qWWdOVGN1TlRrMk5TQTJPUzQxTlRVNElEVTRJRFk1TGprMU9USkROVGt1T0RVMk5pQTNNUzQ0TVRVNElEWXdMamt3TURRZ056UXVNek0wTmlBMk1DNDVNREEwSURjMkxqazJNREpETmpBdU9UQXdNeUEzT1M0MU9EVTRJRFU1TGpnMU5qWWdPREl1TVRBek5pQTFPQ0E0TXk0NU5qQXlRelUzTGpVNU5qWWdPRFF1TXpZek5TQTFOeTR4TmpBeklEZzBMamN5TlRrZ05UWXVOekF3TWlBNE5TNHdOVlkyT0M0NE5qZzBXazAwTVM0d09UazJJRGMyTGprMk1ESkROREV1TURrNU5pQTNOQzR6TXpRMklEUXlMakUwTXpRZ056RXVPREUxT0NBME5DQTJPUzQ1TlRreVF6UTFMamcxTmpZZ05qZ3VNVEF5T1NBME9DNHpOelExSURZM0xqQTFPVGdnTlRFZ05qY3VNRFU1T0VNMU1pNDJOVFU1SURZM0xqQTFPVGdnTlRRdU1qWTRPQ0EyTnk0ME56VXlJRFUxTGpjd01ESWdOamd1TWpRM00xWTROUzQyTnpFeFF6VTBMakkyT0RZZ09EWXVORFF6TlNBMU1pNDJOVFl4SURnMkxqZzFPVFlnTlRFZ09EWXVPRFU1TmtNME9DNHpOelEwSURnMkxqZzFPVFlnTkRVdU9EVTJOaUE0TlM0NE1UWTRJRFEwSURnekxqazJNREpETkRJdU1UUXpOQ0E0TWk0eE1ETTJJRFF4TGpBNU9UY2dOemt1TlRnMU9DQTBNUzR3T1RrMklEYzJMamsyTURKYUlpQm1hV3hzUFNJalJqVkdNRVl3SWlCemRISnZhMlU5SWlOR05VWXdSakFpTHo0S1BIQmhkR2dnWkQwaVRUVTNMamMyTURRZ01UQXdMamcyU0Rjd0xqSXpPVGhETnpFdU1UQXdOQ0F4TURBdU9EWWdOekl1TURJeElERXdNUzR5T0RnZ056TXVNREEyTkNBeE1ESXVNamN6VERjNExqTTVNeklnTVRBM0xqWTJTRFE1TGpZd04wdzFOQzQ1T1RNNElERXdNaTR5TnpORE5UVXVPVEUzTnlBeE1ERXVNelE1SURVMkxqYzRORFFnTVRBd0xqa3hOU0ExTnk0MU9UZ3lJREV3TUM0NE5qVk1OVGN1TnpZd05DQXhNREF1T0RaYUlpQm1hV3hzUFNJalJqVkdNRVl3SWlCemRISnZhMlU5SWlOR05VWXdSakFpTHo0S1BDOW5QZ284WnlCamJHbHdMWEJoZEdnOUluVnliQ2dqWTJ4cGNESmZORjh5TVRRcElqNEtQSEJoZEdnZ1pEMGlUVFkxTGpVZ01USTJMalV5UXprd0xqQTNOamNnTVRJMkxqVXlJREV4TUNBeE1EWXVNRE16SURFeE1DQTRNQzQzTmtNeE1UQWdOVFV1TkRnM05DQTVNQzR3TnpZM0lETTFJRFkxTGpVZ016VkROREF1T1RJek15QXpOU0F5TVNBMU5TNDBPRGMwSURJeElEZ3dMamMyUXpJeElERXdOaTR3TXpNZ05EQXVPVEl6TXlBeE1qWXVOVElnTmpVdU5TQXhNall1TlRKYUlpQnpkSEp2YTJVOUlpTkZRa1ZCUlVFaUlITjBjbTlyWlMxM2FXUjBhRDBpTVRBaUx6NEtQSEJoZEdnZ1pEMGlUVFk0TGpZZ05UZ3VOelpETnpVdU5UTXpNeUExT0M0M05pQTRNQzQzTXpNeklEWXhMak0ySURnMExqSWdOall1TlRaRE9EY3VOalkyTnlBM01TNDNOaUE0T1M0MElEYzJMamsySURnNUxqUWdPREl1TVRaRE9EVXVPVE16TXlBNU1DNDRNalkzSURjNUxqZzJOamNnT1RVdU1UWWdOekV1TWlBNU5TNHhOa2cyTmxZNE55NHpOa2czTVM0eVF6YzBMalkyTmpjZ09EY3VNellnTnpjdU1qWTJOeUE0TlM0Mk1qWTNJRGM1SURneUxqRTJRemMzTGpJMk5qY2dOemd1Tmprek15QTNOQzQyTmpZM0lEYzJMamsySURjeExqSWdOell1T1RaSU5qWldOVGd1TnpaSU5qZ3VObG9pSUdacGJHdzlJaU5GUWtWQlJVRWlMejRLUEhCaGRHZ2daRDBpVFRVNUxqYzJJREV3TUM0ek5rZzNNaTR5TkVNM015NHlPQ0F4TURBdU16WWdOelF1TXpJZ01UQXdMamc0SURjMUxqTTJJREV3TVM0NU1rdzRNUzQySURFd09DNHhOa2cxTUM0MFREVTJMalkwSURFd01TNDVNa00xTnk0Mk9DQXhNREF1T0RnZ05UZ3VOeklnTVRBd0xqTTJJRFU1TGpjMklERXdNQzR6TmxvaUlHWnBiR3c5SWlORlFrVkJSVUVpTHo0S1BDOW5QZ284WnlCamJHbHdMWEJoZEdnOUluVnliQ2dqWTJ4cGNETmZORjh5TVRRcElqNEtQSEJoZEdnZ1pEMGlUVFkxTGpVZ01USTJMalV5UXprd0xqQTNOamNnTVRJMkxqVXlJREV4TUNBeE1EWXVNRE16SURFeE1DQTRNQzQzTmtNeE1UQWdOVFV1TkRnM05DQTVNQzR3TnpZM0lETTFJRFkxTGpVZ016VkROREF1T1RJek15QXpOU0F5TVNBMU5TNDBPRGMwSURJeElEZ3dMamMyUXpJeElERXdOaTR3TXpNZ05EQXVPVEl6TXlBeE1qWXVOVElnTmpVdU5TQXhNall1TlRKYUlpQnpkSEp2YTJVOUlpTkZNRVJHUkVZaUlITjBjbTlyWlMxM2FXUjBhRDBpTVRBaUx6NEtQQzluUGdvOFpHVm1jejRLUEdOc2FYQlFZWFJvSUdsa1BTSmpiR2x3TUY4MFh6SXhOQ0krQ2p4eVpXTjBJSGRwWkhSb1BTSXpNaUlnYUdWcFoyaDBQU0l4TWpnaUlHWnBiR3c5SW5kb2FYUmxJaUIwY21GdWMyWnZjbTA5SW5SeVlXNXpiR0YwWlNnd0lERTNLU0l2UGdvOEwyTnNhWEJRWVhSb1BnbzhZMnhwY0ZCaGRHZ2dhV1E5SW1Oc2FYQXhYelJmTWpFMElqNEtQSEpsWTNRZ2QybGtkR2c5SWpNeUlpQm9aV2xuYUhROUlqRXlPQ0lnWm1sc2JEMGlkMmhwZEdVaUlIUnlZVzV6Wm05eWJUMGlkSEpoYm5Oc1lYUmxLRE15SURFM0tTSXZQZ284TDJOc2FYQlFZWFJvUGdvOFkyeHBjRkJoZEdnZ2FXUTlJbU5zYVhBeVh6UmZNakUwSWo0S1BISmxZM1FnZDJsa2RHZzlJak15SWlCb1pXbG5hSFE5SWpFeU9DSWdabWxzYkQwaWQyaHBkR1VpSUhSeVlXNXpabTl5YlQwaWRISmhibk5zWVhSbEtEWTBJREUzS1NJdlBnbzhMMk5zYVhCUVlYUm9QZ284WTJ4cGNGQmhkR2dnYVdROUltTnNhWEF6WHpSZk1qRTBJajRLUEhKbFkzUWdkMmxrZEdnOUlqTXlJaUJvWldsbmFIUTlJakV5T0NJZ1ptbHNiRDBpZDJocGRHVWlJSFJ5WVc1elptOXliVDBpZEhKaGJuTnNZWFJsS0RrMklERTNLU0l2UGdvOEwyTnNhWEJRWVhSb1BnbzhMMlJsWm5NK0Nqd3ZjM1puUGdvPSJ9";
    /**
     * @notice Sets up the test environment by deploying contracts and initializing test variables
     * @dev This function:
     * - Deploys the DeCup contract and helper config
     * - Creates mock tokens (WETH, WBTC, USDC)
     * - Funds the test user with initial balances
     * - Transfers mock tokens to the test user
     */

    function setUp() external {
        DeployDeCup deployer = new DeployDeCup();
        s_svgDeCupImage = vm.readFile("./img/decup.svg");

        (s_deCup, s_config) = deployer.run();
        s_failingMockToken = new FailingMockToken(1000 ether);

        s_networkConfig = s_config.getConfig();
        s_mockTokenWeth = s_networkConfig.tokenAddresses[0];
        s_mockTokenWbtc = s_networkConfig.tokenAddresses[1];
        s_mockTokenUsdc = s_networkConfig.tokenAddresses[2];
        s_defaultWrapToken = s_networkConfig.defaultPriceFeed;
        // Fund the user
        vm.deal(USER, INITIAL_BALANCE_ETH);

        // Loggin
        console.log(msg.sender);
        console.log("mockToken: ", IERC20Metadata(s_mockTokenWeth).balanceOf(address(deployer)));
        console.log("mockTokenBtc: ", IERC20Metadata(s_mockTokenWbtc).balanceOf(address(deployer)));
        console.log("mockTokenUsdc: ", IERC20Metadata(s_mockTokenUsdc).balanceOf(address(deployer)));

        vm.startPrank(address(deployer));
        IERC20Metadata(s_mockTokenWeth).transfer(USER, INITIAL_ERC20_WETH);
        IERC20Metadata(s_mockTokenWbtc).transfer(USER, INITIAL_ERC20_WBTC);
        IERC20Metadata(s_mockTokenUsdc).transfer(USER, INITIAL_ERC20_USDC);
        vm.stopPrank();

        s_failingMockToken.transfer(USER, INITIAL_ERC20_WETH);
    }
    /*//////////////////////////////////////////////////////////////
                              TEST DEPLOY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests that deployment reverts when token addresses array is empty
     * @dev Verifies the contract correctly enforces non-empty token addresses requirement
     */
    function testDeployRevertsWhenTokenAddressesArrayIsEmpty() public {
        address[] memory tokenAddresses;
        address[] memory priceFeedAddresses = new address[](1);
        priceFeedAddresses[0] = address(0x1);
        vm.expectRevert(DeCup.DeCup__AllowedTokenAddressesMustNotBeEmpty.selector);
        new DeCup(s_svgDeCupImage, tokenAddresses, priceFeedAddresses, s_defaultWrapToken);
    }

    /**
     * @notice Tests that deployment reverts when price feed addresses array is empty
     * @dev Verifies the contract correctly enforces non-empty price feed addresses requirement
     */
    function testDeployRevertsWhenPriceFeedAddressesArrayIsEmpty() public {
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses;
        tokenAddresses[0] = address(s_mockTokenWeth);
        vm.expectRevert(DeCup.DeCup__PriceFeedAddressesMustNotBeEmpty.selector);
        new DeCup(s_svgDeCupImage, tokenAddresses, priceFeedAddresses, s_defaultWrapToken);
    }

    /**
     * @notice Tests that deployment reverts when token addresses and price feed addresses arrays have different lengths
     * @dev Verifies the contract correctly enforces matching array lengths requirement for token and price feed addresses
     */
    function testDeployRevertsWhenTokenAndPriceFeedArrayLengthsMismatch() public {
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](2);
        tokenAddresses[0] = address(s_mockTokenWeth);
        priceFeedAddresses[0] = address(0x1); // Mock price feed address for testing
        priceFeedAddresses[1] = address(0x2); // Mock price feed address for testing
        vm.expectRevert(DeCup.DeCup__TokenAddressesAndPriceFeedAddressesMusBeSameLength.selector);
        new DeCup(s_svgDeCupImage, tokenAddresses, priceFeedAddresses, s_defaultWrapToken);
    }

    /*//////////////////////////////////////////////////////////////
                  NATIVE CURRENCY DEPOSIT / WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests that native currency can be received by the contract
     * @dev Verifies the contract can receive ETH and updates its balance correctly
     */
    function testReceiveNative() public {
        // Arrange
        uint256 amount = 1 ether;

        // Act
        vm.prank(USER);
        (bool success,) = address(s_deCup).call{value: amount}("");

        // Assert
        assert(success);
        assertEq(address(s_deCup).balance, amount);
        assertEq(s_deCup.getTokenCounter(), 1);
    }

    /**
     * @notice Tests that native currency deposit reverts when amount is zero
     * @dev Verifies the contract correctly enforces non-zero deposit amount requirement
     */
    function testReceiveNativeZeroAmount() public {
        // Arrange
        uint256 amount = 0;

        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        (bool success,) = address(s_deCup).call{value: amount}("");
        assert(success);
    }

    /**
     * @notice Tests that native currency can be withdrawn by burning the NFT
     * @dev Verifies that burning an NFT minted with native currency deposit returns the correct amount to the user
     */
    function testBurnNftWithdrawsNativeCurrency() public {
        // Arrange
        uint256 initialBalance = USER.balance;
        uint256 tokenId = 0; // First minted token will have ID 0

        // First deposit 1 ether to get an NFT
        vm.startPrank(USER);
        (bool success,) = address(s_deCup).call{value: 1 ether}("");
        assert(success);

        // Act - Burn the NFT to withdraw the collateral
        s_deCup.burn(tokenId);
        vm.stopPrank();
        // Assert
        assertEq(USER.balance, initialBalance); // User should get back their 1 ether
        assertEq(address(s_deCup).balance, 0); // Contract should have no balance
    }

    function testBurnNftWittNativeCurrencyListedForSale() public {
        // Arrange
        uint256 tokenId = 0; // First minted token will have ID 0

        // First deposit 1 ether to get an NFT
        vm.startPrank(USER);
        (bool success,) = address(s_deCup).call{value: 1 ether}("");
        assert(success);

        // Act - Burn the NFT to withdraw the collateral
        s_deCup.listForSale(tokenId);
        vm.expectRevert(DeCup.DeCup__TokenIsListedForSale.selector);
        s_deCup.burn(tokenId);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                      SINGLE ASSETS DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modifier to deposit a single asset and mint an NFT
     * @dev Helper modifier that deposits USDC tokens and mints an NFT before running the test
     */
    modifier depositSingleAssets() {
        // Arrange
        uint256 depositUsdcAmount = 50e6;
        uint256 initialUsdcBalance = IERC20Metadata(s_mockTokenUsdc).balanceOf(USER);
        // Act - First deposit to mint NFT, then burn to withdraw
        vm.startPrank(USER);
        IERC20Metadata(s_mockTokenUsdc).approve(address(s_deCup), depositUsdcAmount);

        console.log(IERC20Metadata(s_mockTokenUsdc).balanceOf(USER));

        s_deCup.depositSingleAssetAndMint(address(s_mockTokenUsdc), depositUsdcAmount);
        vm.stopPrank();
        _;
    }

    /**
     * @notice Tests that the list of assets deposited for a given token ID is correctly returned
     * @dev Verifies that the contract properly returns the list of assets deposited for a given token ID
     */
    function testGetTokenAssetsList() public depositSingleAssets {
        address[] memory assets = s_deCup.getTokenAssetsList(0);
        assertEq(assets[0], address(s_mockTokenUsdc));
    }

    /**
     * @notice Tests that the single asset deposit and withdrawal works correctly
     * @dev Verifies that the contract properly handles single asset deposits and withdrawals
     */
    function testBurnNftWithdrawsSingleAsset() public depositSingleAssets {
        uint256 initialUsdcBalance = IERC20Metadata(s_mockTokenUsdc).balanceOf(USER);
        uint256 depositUsdcAmount = 50e6;
        vm.prank(USER);
        s_deCup.burn(0);

        uint256 afterBalance = IERC20Metadata(s_mockTokenUsdc).balanceOf(USER);
        assertEq(afterBalance, initialUsdcBalance + depositUsdcAmount);

        // 1000000000
        // 950000000
    }
    /**
     * @notice Tests that native currency can be added to an existing cup
     * @dev Verifies that the contract can receive ETH and updates its balance correctly
     */

    function testAddNativeCollateralToExistingCup() public depositSingleAssets {
        // Arrange
        uint256 initialBalance = address(s_deCup).balance;
        vm.startPrank(USER);
        s_deCup.addNativeCollateralToExistingCup{value: 1 ether}(0);
        vm.stopPrank();
        assertEq(address(s_deCup).balance, initialBalance + 1 ether);
    }

    /**
     * @notice Tests that depositing a single token with a not allowed token reverts
     * @dev Verifies that the contract properly validates that the token is allowed
     */
    function testDepositSingleTokenWithNotAllowedToken() public {
        // Arrange
        vm.startPrank(USER);
        uint256 amount = 1000 * 10 ** 8;
        MockToken notAllowedToken = new MockToken("WETH", "WETH", USER, amount, 18);

        // Act
        notAllowedToken.approve(address(s_deCup), amount);
        vm.expectRevert(DeCup.DeCup__NotAllowedToken.selector);
        s_deCup.depositSingleAssetAndMint(address(notAllowedToken), amount);
        vm.stopPrank();
    }

    /**
     * @notice Tests that depositing a single token and burning works correctly
     * @dev Verifies that the contract properly handles single token deposits and withdrawals
     */
    function testDepositSingleToken() public depositSingleAssets {
        // Arrange
        vm.startPrank(USER);
        uint256 tokenId = 0; // First minted token will have ID 0
        s_deCup.burn(tokenId); // Burn NFT to withdraw collateral
        vm.stopPrank();

        assertEq(IERC20Metadata(s_mockTokenUsdc).balanceOf(address(s_deCup)), 0);
    }

    /**
     * @notice Tests that burning a non-existent NFT reverts with the correct error
     * @dev Verifies that the contract properly validates token existence before burning
     */
    function testRevertWhenBurningNonExistentNft() public {
        vm.prank(USER);
        vm.expectRevert(DeCup.DeCup__TokenDoesNotExist.selector);
        s_deCup.burn(999); // Try to burn non-existent token
    }

    /**
     * @notice Tests that the contract reverts when depositing a single asset with a zero amount
     * @dev Verifies that the contract properly validates non-zero amounts for token deposits
     */
    function testDepositSingleAssetZeroAmount() public {
        // Arrange
        vm.startPrank(USER);
        // Act / Assert
        IERC20Metadata(s_mockTokenUsdc).approve(address(s_deCup), 1000 * 10 ** 18);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        s_deCup.depositSingleAssetAndMint(address(s_mockTokenUsdc), 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    MULTIPLE ASSETS DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Modifier to deposit multiple assets and mint an NFT
     * @dev Helper modifier that:
     * - Deposits 1.5 WETH, 100 WBTC, and 50 USDC tokens
     * - Deposits 1 ETH native currency
     * - Approves token transfers
     * - Mints an NFT collateralized by all assets
     * - Used to set up test state for multiple asset tests
     */
    modifier depositMultiAssets() {
        // Arrange
        uint256 amount = 1 ether;
        uint256 depositWethAmount = 1.5 ether;
        uint256 depositWbtcAmount = 100e8;
        uint256 depositUsdcAmount = 50e6;
        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        // Act - First deposit to mint NFT, then burn to withdraw
        vm.startPrank(USER);
        IERC20Metadata(s_mockTokenWeth).approve(address(s_deCup), depositWethAmount);
        IERC20Metadata(s_mockTokenWbtc).approve(address(s_deCup), depositWbtcAmount);
        IERC20Metadata(s_mockTokenUsdc).approve(address(s_deCup), depositUsdcAmount);

        console.log(IERC20Metadata(s_mockTokenUsdc).balanceOf(USER));

        tokens[0] = address(s_mockTokenWeth);
        tokens[1] = address(s_mockTokenWbtc);
        tokens[2] = address(s_mockTokenUsdc);

        amounts[0] = depositWethAmount;
        amounts[1] = depositWbtcAmount;
        amounts[2] = depositUsdcAmount;

        s_deCup.depositMultipleAssetsAndMint{value: amount}(tokens, amounts);
        vm.stopPrank();
        _;
    }

    /**
     * @notice Tests that token collateral can be added to an existing cup
     * @dev Verifies that the contract can receive ERC20 tokens and updates the collateral balance correctly
     */
    function testAddTokenCollateralToExistingCup() public depositSingleAssets {
        // Arrange
        uint256 initialBalance = s_deCup.getCollateralDeposited(0, address(s_mockTokenUsdc));
        uint256 initialUsdcBalance = IERC20Metadata(s_mockTokenUsdc).balanceOf(address(s_deCup));
        vm.startPrank(USER);
        s_deCup.addTokenCollateralToExistingCup(address(s_mockTokenUsdc), 5e6, 0);
        vm.stopPrank();
        uint256 afterBalance = s_deCup.getCollateralDeposited(0, address(s_mockTokenUsdc));
        uint256 afterUsdcBalance = IERC20Metadata(s_mockTokenUsdc).balanceOf(address(s_deCup));
        assertEq(afterBalance, initialBalance + 5e6);
        assertEq(afterUsdcBalance, initialUsdcBalance);
    }

    /**
     * @notice Tests that adding not allowed token collateral to an existing cup reverts
     * @dev Verifies that the contract properly validates that the token is allowed
     */
    function testRevertWhenAddingNotAllowedTokenCollateralToExistingCup() public depositSingleAssets {
        // Arrange
        vm.startPrank(USER);
        vm.expectRevert(DeCup.DeCup__NotAllowedToken.selector);
        s_deCup.addTokenCollateralToExistingCup(address(s_failingMockToken), 5e6, 0);
        vm.stopPrank();
    }

    /**
     * @notice Tests successful deposit of multiple assets (ERC20 tokens and native currency) and minting of NFT
     * @dev Tests that:
     * - Multiple ERC20 tokens and native currency can be deposited in a single transaction
     * - NFT is minted with correct collateral data
     * - All collateral can be withdrawn by burning the NFT
     * - Final balances match initial balances after full cycle
     */
    function testDepositMultipleAssetsAndMintSuccess() public depositMultiAssets {
        // Arrange
        // Act
        vm.startPrank(USER);
        uint256 userNftBalance = s_deCup.balanceOf(USER);
        uint256 tokenId = 0; // First minted token will have ID 0
        s_deCup.burn(tokenId); // Burn NFT to withdraw all collateral
        uint256 userNftBalanceAfterBurn = s_deCup.balanceOf(USER);
        vm.stopPrank();

        // Assert
        assertEq(IERC20Metadata(s_mockTokenWeth).balanceOf(address(s_deCup)), 0);
        assertEq(IERC20Metadata(s_mockTokenWbtc).balanceOf(address(s_deCup)), 0);
        assertEq(IERC20Metadata(s_mockTokenUsdc).balanceOf(address(s_deCup)), 0);
        assertEq(address(s_deCup).balance, 0);
        assert(userNftBalance > userNftBalanceAfterBurn);
        assertEq(userNftBalanceAfterBurn, 0);
    }

    /**
     * @notice Tests that the contract reverts when depositing multiple assets with mismatched array lengths
     * @dev Verifies that the contract properly validates that the token addresses and amounts arrays have the same length
     * @dev Uses a combination of valid and invalid lengths to test the validation logic
     */
    function testRevertsWhenDepositingMultipleAssetsWithMismatchedArrayLengths() public {
        // Arrange
        address[] memory tokenAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](1); // Different length
        tokenAddresses[0] = address(s_mockTokenUsdc);
        tokenAddresses[1] = address(s_failingMockToken);
        amounts[0] = 500 * 10 ** 18;

        // Act / Assert
        vm.prank(USER);
        vm.expectRevert(DeCup.DeCup__TokenAddressesAndAmountsMusBeSameLength.selector);
        s_deCup.depositMultipleAssetsAndMint(tokenAddresses, amounts);
    }

    /**
     * @notice Tests that the contract reverts when depositing multiple assets with a zero amount
     * @dev Verifies that the contract properly validates non-zero amounts for each token deposit
     * @dev Uses a combination of valid and zero amounts to test the validation logic
     */
    function testRevertsWhenDepositingMultipleAssetsWithZeroAmount() public {
        // Arrange
        address[] memory tokenAddresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokenAddresses[0] = address(s_mockTokenUsdc);
        tokenAddresses[1] = address(s_failingMockToken);
        amounts[0] = 5e6;
        amounts[1] = 0; // Zero amount should fail

        // Act / Assert
        vm.startPrank(USER);
        IERC20Metadata(s_mockTokenUsdc).approve(address(s_deCup), amounts[0]);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        s_deCup.depositMultipleAssetsAndMint(tokenAddresses, amounts);
        vm.stopPrank();
    }

    /**
     * @notice Tests that the contract reverts when a token transfer fails during multiple asset deposit
     * @dev Verifies that the contract properly handles failed token transfers by reverting the transaction
     * @dev Uses a mock token configured to fail transfers to simulate the error condition
     */
    function testDepositMultipleAssetsAndMintTransferFailed() public {
        // Arrange - Set failing token to fail transfers
        address[] memory tokenAddresses = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenAddresses[0] = address(s_failingMockToken);
        amounts[0] = 500 * 10 ** 18;

        // Act / Assert
        vm.startPrank(USER);
        s_failingMockToken.approve(address(s_deCup), amounts[0]);
        s_failingMockToken.setShouldFailTransfer(true); // Make the transfer return false
        vm.expectRevert(DeCup.DeCup__TransferFailed.selector);
        s_deCup.depositMultipleAssetsAndMint(tokenAddresses, amounts);
        vm.stopPrank();
    }

    /**
     * @notice Tests that the contract reverts when depositing empty arrays without native currency
     * @dev Verifies that the contract reverts when attempting to deposit empty arrays without any native currency value
     * @dev This test ensures the contract properly validates that at least one form of collateral is provided
     */
    function testRevertsWhenDepositingEmptyArraysWithoutNativeCurrency() public {
        // Arrange
        address[] memory tokenAddresses = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        // Act - Should succeed but mint an NFT with no collateral
        vm.prank(USER);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        s_deCup.depositMultipleAssetsAndMint(tokenAddresses, amounts);
    }

    /**
     * @notice Tests that the tokenURI is correctly generated for a native currency deposit
     * @dev Verifies that depositing native currency and ERC20 tokens results in the expected tokenURI metadata
     */
    function testDepositdNativeCurrencyMintedTokenURI() public depositMultiAssets {
        // Arrange / Act
        assertEq(keccak256(bytes(s_nativeDepositTokenURI)), keccak256(bytes(s_deCup.tokenURI(0))));
    }

    /**
     * @notice Tests that the TCL is correctly calculated for a native currency deposit
     * @dev Verifies that depositing native currency and ERC20 tokens results in the expected TCL
     */
    function testGetTokenIdTCL() public {
        // Arrange
        uint256 amount = 1 ether;
        uint256 tokenId = 0;

        // Act
        vm.prank(USER);
        (bool success,) = address(s_deCup).call{value: amount}("");
        uint256 tcl = s_deCup.getTokenIdTCL(tokenId);

        // Assert
        assert(success);
        assert(tcl > 0);
    }

    /**
     * @notice Tests that the TCL is correctly calculated for a native currency deposit
     * @dev Verifies that depositing native currency and ERC20 tokens results in the expected TCL
     */
    function testGetAssetTokenIdTCL() public depositSingleAssets {
        // Arrange
        uint256 depositUsdcAmount = 50e6;
        // ACT
        uint256 tcl = s_deCup.getTokenIdTCL(0);
        uint256 usdcValue = s_deCup.getUsdcUSDValue(address(s_mockTokenUsdc), depositUsdcAmount);

        // Assert
        assertEq(tcl, usdcValue); //50000 000 000 000 000 000 000
    }

    /**
     * @notice Tests that the NFT owner is correctly set to the user
     * @dev Verifies that the NFT owner is correctly set to the user after depositing native currency
     */
    function testCollateralNftOwner() public {
        // Arrange
        uint256 amount = 1 ether;
        uint256 tokenId = 0;

        // Act
        vm.prank(USER);
        (bool success,) = address(s_deCup).call{value: amount}("");
        address owner = s_deCup.ownerOf(tokenId);

        // Assert
        assert(success);
        assertEq(owner, USER);
    }

    /**
     * @notice Tests that the token is listed for sale
     * @dev Verifies that the token is listed for sale after listing
     */
    function testListForSale() public {
        // Arrange
        uint256 tokenId = 0;

        // Act
        vm.startPrank(USER);
        (bool success,) = address(s_deCup).call{value: 1 ether}("");
        s_deCup.listForSale(tokenId);

        // Assert
        assert(success);
        assert(s_deCup.getIsListedForSale(tokenId));
    }

    /**
     * @notice Tests that the token is removed from sale
     * @dev Verifies that the token is removed from sale after removing
     */
    function testRemoveFromSale() public {
        // Arrange
        uint256 tokenId = 0;

        // Act
        vm.startPrank(USER);
        (bool success,) = address(s_deCup).call{value: 1 ether}("");
        s_deCup.listForSale(tokenId);
        s_deCup.removeFromSale(tokenId);
        vm.stopPrank();

        // Assert
        assert(success);
        assert(!s_deCup.getIsListedForSale(tokenId));
    }
}
