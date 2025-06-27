// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DeCup} from "src/DeCup.sol";
import {DeployDeCup} from "script/DeployDeCup.s.sol";
import {HelperConfigDeCup} from "script/HelperConfigDeCup.s.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockToken} from "../mocks/MockToken.sol";
import {FailingMockToken} from "../mocks/MockToken.sol";

contract DeCupTest is Test {
    DeCup public deCup;
    HelperConfigDeCup public s_config;
    HelperConfigDeCup.NetworkConfig public s_networkConfig;
    FailingMockToken public s_failingMockToken;
    DeployDeCup public s_deployer;

    string public s_svgDeCupImage;

    address public s_mockTokenWeth;
    address public s_mockTokenUsdc;
    address public s_defaultWrapToken;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_BALANCE_ETH = 1000 ether;
    uint256 public constant INITIAL_ERC20_WETH = 1000e18;
    uint256 public constant INITIAL_ERC20_USDC = 1000e6;

    string public constant s_nativeDepositTokenURI =
        "data:application/json;base64,eyJ0b2tlbklkIjoiMCIsIm5hbWUiOiJEZUN1cCMwICQ1NTAwMCIsImRlc2NyaXB0aW9uIjoiRGVjZW50cmFsaXplZCBDdXAgb2YgYXNzZXRzIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjoiVENMIiwidmFsdWUiOiI1NTAwMCBVU0QifSx7InRyYWl0X3R5cGUiOiJFVEgiLCJ2YWx1ZSI6IjEwMDAwMDAwMDAwMDAwMDAwMDAifSx7InRyYWl0X3R5cGUiOiJXRVRIIiwidmFsdWUiOiIxNTAwMDAwMDAwMDAwMDAwMDAwIn0seyJ0cmFpdF90eXBlIjoiVVNEQyIsInZhbHVlIjoiNTAwMDAwMDAifV0sImltYWdlIjoiZGF0YTppbWFnZS9zdmcreG1sO2Jhc2U2NCxQSE4yWnlCM2FXUjBhRDBpTVRVMklpQm9aV2xuYUhROUlqRTFNQ0lnZG1sbGQwSnZlRDBpTUNBd0lERTFOaUF4TlRBaUlHWnBiR3c5SW01dmJtVWlJSGh0Ykc1elBTSm9kSFJ3T2k4dmQzZDNMbmN6TG05eVp5OHlNREF3TDNOMlp5SStDanh3WVhSb0lHUTlJazB4TWpFZ016QkRNVFl4SURZd0xqTXpNek1nTVRZeElEa3dMalkyTmpjZ01USXhJREV5TVNJZ2MzUnliMnRsUFNJak5ETTVRVVpGSWlCemRISnZhMlV0ZDJsa2RHZzlJakV3SWk4K0NqeHlaV04wSUhnOUlqazJJaUIzYVdSMGFEMGlNeklpSUdobGFXZG9kRDBpTVRVd0lpQm1hV3hzUFNJak5ETTVRVVpGSWk4K0NqeHlaV04wSUhnOUlqWTBJaUIzYVdSMGFEMGlNeklpSUdobGFXZG9kRDBpTVRVd0lpQm1hV3hzUFNJak5FVkJNVVpHSWk4K0NqeHlaV04wSUhnOUlqTXlJaUIzYVdSMGFEMGlNeklpSUdobGFXZG9kRDBpTVRVd0lpQm1hV3hzUFNJak5qTkJRMFpHSWk4K0NqeHlaV04wSUhkcFpIUm9QU0l6TWlJZ2FHVnBaMmgwUFNJeE5UQWlJR1pwYkd3OUlpTTNPVUk0UmtZaUx6NEtQR2NnWTJ4cGNDMXdZWFJvUFNKMWNtd29JMk5zYVhBd1h6UmZNakUwS1NJK0NqeHdZWFJvSUdROUlrMDJNeTQxSURFeU5pNDFNa000T0M0d056WTNJREV5Tmk0MU1pQXhNRGdnTVRBMkxqQXpNeUF4TURnZ09EQXVOelpETVRBNElEVTFMalE0TnpRZ09EZ3VNRGMyTnlBek5TQTJNeTQxSURNMVF6TTRMamt5TXpNZ016VWdNVGtnTlRVdU5EZzNOQ0F4T1NBNE1DNDNOa014T1NBeE1EWXVNRE16SURNNExqa3lNek1nTVRJMkxqVXlJRFl6TGpVZ01USTJMalV5V2lJZ2MzUnliMnRsUFNKM2FHbDBaU0lnYzNSeWIydGxMWGRwWkhSb1BTSXhNQ0l2UGdvOEwyYytDanhuSUdOc2FYQXRjR0YwYUQwaWRYSnNLQ05qYkdsd01WODBYekl4TkNraVBnbzhjR0YwYUNCa1BTSk5Oak11TlNBeE1qWXVOVEpET0RndU1EYzJOeUF4TWpZdU5USWdNVEE0SURFd05pNHdNek1nTVRBNElEZ3dMamMyUXpFd09DQTFOUzQwT0RjMElEZzRMakEzTmpjZ016VWdOak11TlNBek5VTXpPQzQ1TWpNeklETTFJREU1SURVMUxqUTROelFnTVRrZ09EQXVOelpETVRrZ01UQTJMakF6TXlBek9DNDVNak16SURFeU5pNDFNaUEyTXk0MUlERXlOaTQxTWxvaUlITjBjbTlyWlQwaUkwWTFSakJHTUNJZ2MzUnliMnRsTFhkcFpIUm9QU0l4TUNJdlBnbzhjR0YwYUNCa1BTSk5OVEVnTlRrdU1qWkROVEl1TmpVMk15QTFPUzR5TmlBMU15NDRNRGNnTlRrdU5qY3pOU0ExTkM0MU5EWTVJRFl3TGpReE16TkROVFV1TWpnMk5pQTJNUzR4TlRNeUlEVTFMamN3TURJZ05qSXVNekEwSURVMUxqY3dNRElnTmpNdU9UWXdNbFkyTnk0eE1qWXlRelUwTGpJME5qRWdOall1TkRNeE15QTFNaTQyTkRJeklEWTJMakExT1RnZ05URWdOall1TURVNU9FTTBPQzR4TURreklEWTJMakExT1RnZ05EVXVNek0zTVNBMk55NHlNRGd6SURRekxqSTVNeUEyT1M0eU5USXlRelF4TGpJME9EZ2dOekV1TWprMk15QTBNQzR3T1RrMklEYzBMakEyT1RNZ05EQXVNRGs1TmlBM05pNDVOakF5UXpRd0xqQTVPVGNnTnprdU9EVXhJRFF4TGpJME9Ea2dPREl1TmpJek1TQTBNeTR5T1RNZ09EUXVOalkzTWtNME5TNHpNemN4SURnMkxqY3hNVE1nTkRndU1UQTVNaUE0Tnk0NE5UazJJRFV4SURnM0xqZzFPVFpETlRJdU5qUXlOU0E0Tnk0NE5UazJJRFUwTGpJME5pQTROeTQwT0RjMElEVTFMamN3TURJZ09EWXVOemt5TWxZNE9TNDVOakF5UXpVMUxqY3dNRElnT1RFdU5qRTJNU0ExTlM0eU9EWTBJRGt5TGpjMk5qTWdOVFF1TlRRMk9TQTVNeTQxTURZeFF6VXpMamd3TnlBNU5DNHlORFU1SURVeUxqWTFOak1nT1RRdU5qWXdOQ0ExTVNBNU5DNDJOakEwU0RNNExqVldOVGt1TWpaSU5URmFUVFUyTGpjd01ESWdOamd1T0RZNE5FTTFOeTR4TmpBMUlEWTVMakU1TWpZZ05UY3VOVGsyTlNBMk9TNDFOVFU0SURVNElEWTVMamsxT1RKRE5Ua3VPRFUyTmlBM01TNDRNVFU0SURZd0xqa3dNRFFnTnpRdU16TTBOaUEyTUM0NU1EQTBJRGMyTGprMk1ESkROakF1T1RBd015QTNPUzQxT0RVNElEVTVMamcxTmpZZ09ESXVNVEF6TmlBMU9DQTRNeTQ1TmpBeVF6VTNMalU1TmpZZ09EUXVNell6TlNBMU55NHhOakF6SURnMExqY3lOVGtnTlRZdU56QXdNaUE0TlM0d05WWTJPQzQ0TmpnMFdrMDBNUzR3T1RrMklEYzJMamsyTURKRE5ERXVNRGs1TmlBM05DNHpNelEySURReUxqRTBNelFnTnpFdU9ERTFPQ0EwTkNBMk9TNDVOVGt5UXpRMUxqZzFOallnTmpndU1UQXlPU0EwT0M0ek56UTFJRFkzTGpBMU9UZ2dOVEVnTmpjdU1EVTVPRU0xTWk0Mk5UVTVJRFkzTGpBMU9UZ2dOVFF1TWpZNE9DQTJOeTQwTnpVeUlEVTFMamN3TURJZ05qZ3VNalEzTTFZNE5TNDJOekV4UXpVMExqSTJPRFlnT0RZdU5EUXpOU0ExTWk0Mk5UWXhJRGcyTGpnMU9UWWdOVEVnT0RZdU9EVTVOa00wT0M0ek56UTBJRGcyTGpnMU9UWWdORFV1T0RVMk5pQTROUzQ0TVRZNElEUTBJRGd6TGprMk1ESkROREl1TVRRek5DQTRNaTR4TURNMklEUXhMakE1T1RjZ056a3VOVGcxT0NBME1TNHdPVGsySURjMkxqazJNREphSWlCbWFXeHNQU0lqUmpWR01FWXdJaUJ6ZEhKdmEyVTlJaU5HTlVZd1JqQWlMejRLUEhCaGRHZ2daRDBpVFRVM0xqYzJNRFFnTVRBd0xqZzJTRGN3TGpJek9UaEROekV1TVRBd05DQXhNREF1T0RZZ056SXVNREl4SURFd01TNHlPRGdnTnpNdU1EQTJOQ0F4TURJdU1qY3pURGM0TGpNNU16SWdNVEEzTGpZMlNEUTVMall3TjB3MU5DNDVPVE00SURFd01pNHlOek5ETlRVdU9URTNOeUF4TURFdU16UTVJRFUyTGpjNE5EUWdNVEF3TGpreE5TQTFOeTQxT1RneUlERXdNQzQ0TmpWTU5UY3VOell3TkNBeE1EQXVPRFphSWlCbWFXeHNQU0lqUmpWR01FWXdJaUJ6ZEhKdmEyVTlJaU5HTlVZd1JqQWlMejRLUEM5blBnbzhaeUJqYkdsd0xYQmhkR2c5SW5WeWJDZ2pZMnhwY0RKZk5GOHlNVFFwSWo0S1BIQmhkR2dnWkQwaVRUWTFMalVnTVRJMkxqVXlRemt3TGpBM05qY2dNVEkyTGpVeUlERXhNQ0F4TURZdU1ETXpJREV4TUNBNE1DNDNOa014TVRBZ05UVXVORGczTkNBNU1DNHdOelkzSURNMUlEWTFMalVnTXpWRE5EQXVPVEl6TXlBek5TQXlNU0ExTlM0ME9EYzBJREl4SURnd0xqYzJRekl4SURFd05pNHdNek1nTkRBdU9USXpNeUF4TWpZdU5USWdOalV1TlNBeE1qWXVOVEphSWlCemRISnZhMlU5SWlORlFrVkJSVUVpSUhOMGNtOXJaUzEzYVdSMGFEMGlNVEFpTHo0S1BIQmhkR2dnWkQwaVRUWTRMallnTlRndU56WkROelV1TlRNek15QTFPQzQzTmlBNE1DNDNNek16SURZeExqTTJJRGcwTGpJZ05qWXVOVFpET0RjdU5qWTJOeUEzTVM0M05pQTRPUzQwSURjMkxqazJJRGc1TGpRZ09ESXVNVFpET0RVdU9UTXpNeUE1TUM0NE1qWTNJRGM1TGpnMk5qY2dPVFV1TVRZZ056RXVNaUE1TlM0eE5rZzJObFk0Tnk0ek5rZzNNUzR5UXpjMExqWTJOamNnT0RjdU16WWdOemN1TWpZMk55QTROUzQyTWpZM0lEYzVJRGd5TGpFMlF6YzNMakkyTmpjZ056Z3VOamt6TXlBM05DNDJOalkzSURjMkxqazJJRGN4TGpJZ056WXVPVFpJTmpaV05UZ3VOelpJTmpndU5sb2lJR1pwYkd3OUlpTkZRa1ZCUlVFaUx6NEtQSEJoZEdnZ1pEMGlUVFU1TGpjMklERXdNQzR6TmtnM01pNHlORU0zTXk0eU9DQXhNREF1TXpZZ056UXVNeklnTVRBd0xqZzRJRGMxTGpNMklERXdNUzQ1TWt3NE1TNDJJREV3T0M0eE5rZzFNQzQwVERVMkxqWTBJREV3TVM0NU1rTTFOeTQyT0NBeE1EQXVPRGdnTlRndU56SWdNVEF3TGpNMklEVTVMamMySURFd01DNHpObG9pSUdacGJHdzlJaU5GUWtWQlJVRWlMejRLUEM5blBnbzhaeUJqYkdsd0xYQmhkR2c5SW5WeWJDZ2pZMnhwY0ROZk5GOHlNVFFwSWo0S1BIQmhkR2dnWkQwaVRUWTFMalVnTVRJMkxqVXlRemt3TGpBM05qY2dNVEkyTGpVeUlERXhNQ0F4TURZdU1ETXpJREV4TUNBNE1DNDNOa014TVRBZ05UVXVORGczTkNBNU1DNHdOelkzSURNMUlEWTFMalVnTXpWRE5EQXVPVEl6TXlBek5TQXlNU0ExTlM0ME9EYzBJREl4SURnd0xqYzJRekl4SURFd05pNHdNek1nTkRBdU9USXpNeUF4TWpZdU5USWdOalV1TlNBeE1qWXVOVEphSWlCemRISnZhMlU5SWlORk1FUkdSRVlpSUhOMGNtOXJaUzEzYVdSMGFEMGlNVEFpTHo0S1BDOW5QZ284WkdWbWN6NEtQR05zYVhCUVlYUm9JR2xrUFNKamJHbHdNRjgwWHpJeE5DSStDanh5WldOMElIZHBaSFJvUFNJek1pSWdhR1ZwWjJoMFBTSXhNamdpSUdacGJHdzlJbmRvYVhSbElpQjBjbUZ1YzJadmNtMDlJblJ5WVc1emJHRjBaU2d3SURFM0tTSXZQZ284TDJOc2FYQlFZWFJvUGdvOFkyeHBjRkJoZEdnZ2FXUTlJbU5zYVhBeFh6UmZNakUwSWo0S1BISmxZM1FnZDJsa2RHZzlJak15SWlCb1pXbG5hSFE5SWpFeU9DSWdabWxzYkQwaWQyaHBkR1VpSUhSeVlXNXpabTl5YlQwaWRISmhibk5zWVhSbEtETXlJREUzS1NJdlBnbzhMMk5zYVhCUVlYUm9QZ284WTJ4cGNGQmhkR2dnYVdROUltTnNhWEF5WHpSZk1qRTBJajRLUEhKbFkzUWdkMmxrZEdnOUlqTXlJaUJvWldsbmFIUTlJakV5T0NJZ1ptbHNiRDBpZDJocGRHVWlJSFJ5WVc1elptOXliVDBpZEhKaGJuTnNZWFJsS0RZMElERTNLU0l2UGdvOEwyTnNhWEJRWVhSb1BnbzhZMnhwY0ZCaGRHZ2dhV1E5SW1Oc2FYQXpYelJmTWpFMElqNEtQSEpsWTNRZ2QybGtkR2c5SWpNeUlpQm9aV2xuYUhROUlqRXlPQ0lnWm1sc2JEMGlkMmhwZEdVaUlIUnlZVzV6Wm05eWJUMGlkSEpoYm5Oc1lYUmxLRGsySURFM0tTSXZQZ284TDJOc2FYQlFZWFJvUGdvOEwyUmxabk0rQ2p3dmMzWm5QZ289In0=";

    /**
     * @notice Sets up the test environment by deploying contracts and initializing test variables
     * @dev This function:
     * - Deploys the DeCup contract and helper config
     * - Creates mock tokens (WETH, WBTC, USDC)
     * - Funds the test user with initial balances
     * - Transfers mock tokens to the test user
     */
    function setUp() external {
        s_deployer = new DeployDeCup();
        s_svgDeCupImage = vm.readFile("./img/decup.svg");

        (deCup, s_config) = s_deployer.run();
        s_failingMockToken = new FailingMockToken(1000 ether);

        s_networkConfig = s_config.getConfig();
        s_mockTokenWeth = s_networkConfig.tokenAddresses[0];
        s_mockTokenUsdc = s_networkConfig.tokenAddresses[1];
        s_defaultWrapToken = s_networkConfig.defaultPriceFeed;
        // Fund the user
        vm.deal(USER, INITIAL_BALANCE_ETH);

        // Loggin
        console.log(msg.sender);
        console.log("mockToken: ", IERC20Metadata(s_mockTokenWeth).balanceOf(address(s_deployer)));
        console.log("mockTokenUsdc: ", IERC20Metadata(s_mockTokenUsdc).balanceOf(address(s_deployer)));

        vm.startPrank(address(s_deployer));
        IERC20Metadata(s_mockTokenWeth).transfer(USER, INITIAL_ERC20_WETH);
        IERC20Metadata(s_mockTokenUsdc).transfer(USER, INITIAL_ERC20_USDC);
        vm.stopPrank();

        s_failingMockToken.transfer(USER, INITIAL_ERC20_WETH);
    }

    modifier mintDeCupNft() {
        // vm.prank(USER);
        // deCup.mint(USER, 0);
        _;
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
        (bool success,) = address(deCup).call{value: amount}("");

        // Assert
        assert(success);
        assertEq(address(deCup).balance, amount);
        assertEq(deCup.getTokenCounter(), 1);
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
        (bool success,) = address(deCup).call{value: amount}("");
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
        (bool success,) = address(deCup).call{value: 1 ether}("");
        assert(success);

        // Act - Burn the NFT to withdraw the collateral
        deCup.burn(tokenId);
        vm.stopPrank();
        // Assert
        assertEq(USER.balance, initialBalance); // User should get back their 1 ether
        assertEq(address(deCup).balance, 0); // Contract should have no balance
    }

    function testBurnNftRevertsWhenNativeCurrencyListedForSale() public {
        // Arrange
        uint256 tokenId = 0; // First minted token will have ID 0

        // First deposit 1 ether to get an NFT
        vm.prank(USER);
        (bool success,) = address(deCup).call{value: 1 ether}("");
        assert(success);

        // Act - Burn the NFT to withdraw the collateral
        console.log("tokenId owner:", deCup.ownerOf(tokenId));
        console.log("USER", USER);
        console.log("deCup owner", deCup.owner());
        console.log("msg.sender", msg.sender);

        vm.prank(address(msg.sender));
        deCup.listForSale(tokenId);

        vm.prank(USER);
        vm.expectRevert(DeCup.DeCup__TokenIsListedForSale.selector);
        deCup.burn(tokenId);
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
        IERC20Metadata(s_mockTokenUsdc).approve(address(deCup), depositUsdcAmount);

        console.log(IERC20Metadata(s_mockTokenUsdc).balanceOf(USER));

        deCup.depositSingleAssetAndMint(address(s_mockTokenUsdc), depositUsdcAmount);
        vm.stopPrank();
        _;
    }

    /**
     * @notice Tests that the list of assets deposited for a given token ID is correctly returned
     * @dev Verifies that the contract properly returns the list of assets deposited for a given token ID
     */
    function testGetTokenAssetsList() public depositSingleAssets {
        address[] memory assets = deCup.getTokenAssetsList(0);
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
        deCup.burn(0);

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
        uint256 initialBalance = address(deCup).balance;
        vm.startPrank(USER);
        deCup.addNativeCollateralToExistingCup{value: 1 ether}(0);
        vm.stopPrank();
        assertEq(address(deCup).balance, initialBalance + 1 ether);
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
        notAllowedToken.approve(address(deCup), amount);
        vm.expectRevert(DeCup.DeCup__NotAllowedToken.selector);
        deCup.depositSingleAssetAndMint(address(notAllowedToken), amount);
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
        deCup.burn(tokenId); // Burn NFT to withdraw collateral
        vm.stopPrank();

        assertEq(IERC20Metadata(s_mockTokenUsdc).balanceOf(address(deCup)), 0);
    }

    /**
     * @notice Tests that burning a non-existent NFT reverts with the correct error
     * @dev Verifies that the contract properly validates token existence before burning
     */
    function testRevertWhenBurningNonExistentNft() public {
        vm.prank(USER);
        vm.expectRevert(DeCup.DeCup__TokenDoesNotExist.selector);
        deCup.burn(999); // Try to burn non-existent token
    }

    /**
     * @notice Tests that the contract reverts when depositing a single asset with a zero amount
     * @dev Verifies that the contract properly validates non-zero amounts for token deposits
     */
    function testDepositSingleAssetZeroAmount() public {
        // Arrange
        vm.startPrank(USER);
        // Act / Assert
        IERC20Metadata(s_mockTokenUsdc).approve(address(deCup), 1000 * 10 ** 18);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        deCup.depositSingleAssetAndMint(address(s_mockTokenUsdc), 0);
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
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        // Act - First deposit to mint NFT, then burn to withdraw
        vm.startPrank(USER);
        IERC20Metadata(s_mockTokenWeth).approve(address(deCup), depositWethAmount);
        IERC20Metadata(s_mockTokenUsdc).approve(address(deCup), depositUsdcAmount);

        console.log(IERC20Metadata(s_mockTokenUsdc).balanceOf(USER));

        tokens[0] = address(s_mockTokenWeth);
        tokens[1] = address(s_mockTokenUsdc);

        amounts[0] = depositWethAmount;
        amounts[1] = depositUsdcAmount;

        deCup.depositMultipleAssetsAndMint{value: amount}(tokens, amounts);
        vm.stopPrank();
        _;
    }

    /**
     * @notice Tests that token collateral can be added to an existing cup
     * @dev Verifies that the contract can receive ERC20 tokens and updates the collateral balance correctly
     */
    function testAddTokenCollateralToExistingCup() public depositSingleAssets {
        // Arrange
        uint256 initialBalance = deCup.getCollateralBalance(0, address(s_mockTokenUsdc));
        uint256 initialUsdcBalance = IERC20Metadata(s_mockTokenUsdc).balanceOf(address(deCup));
        vm.startPrank(USER);
        deCup.addTokenCollateralToExistingCup(address(s_mockTokenUsdc), 5e6, 0);
        vm.stopPrank();
        uint256 afterBalance = deCup.getCollateralBalance(0, address(s_mockTokenUsdc));
        uint256 afterUsdcBalance = IERC20Metadata(s_mockTokenUsdc).balanceOf(address(deCup));
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
        deCup.addTokenCollateralToExistingCup(address(s_failingMockToken), 5e6, 0);
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
        uint256 userNftBalance = deCup.balanceOf(USER);
        uint256 tokenId = 0; // First minted token will have ID 0
        deCup.burn(tokenId); // Burn NFT to withdraw all collateral
        uint256 userNftBalanceAfterBurn = deCup.balanceOf(USER);
        vm.stopPrank();

        // Assert
        assertEq(IERC20Metadata(s_mockTokenWeth).balanceOf(address(deCup)), 0);
        assertEq(IERC20Metadata(s_mockTokenUsdc).balanceOf(address(deCup)), 0);
        assertEq(address(deCup).balance, 0);
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
        deCup.depositMultipleAssetsAndMint(tokenAddresses, amounts);
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
        IERC20Metadata(s_mockTokenUsdc).approve(address(deCup), amounts[0]);
        vm.expectRevert(DeCup.DeCup__AmountMustBeGreaterThanZero.selector);
        deCup.depositMultipleAssetsAndMint(tokenAddresses, amounts);
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
        s_failingMockToken.approve(address(deCup), amounts[0]);
        s_failingMockToken.setShouldFailTransfer(true); // Make the transfer return false
        vm.expectRevert(DeCup.DeCup__TransferFailed.selector);
        deCup.depositMultipleAssetsAndMint(tokenAddresses, amounts);
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
        deCup.depositMultipleAssetsAndMint(tokenAddresses, amounts);
    }

    /**
     * @notice Tests that the tokenURI is correctly generated for a native currency deposit
     * @dev Verifies that depositing native currency and ERC20 tokens results in the expected tokenURI metadata
     */
    function testDepositdNativeCurrencyMintedTokenURI() public depositMultiAssets {
        // Arrange / Act
        assertEq(keccak256(bytes(s_nativeDepositTokenURI)), keccak256(bytes(deCup.tokenURI(0))));
    }

    /**
     * @notice Tests that the TCL is correctly calculated for a native currency deposit
     * @dev Verifies that depositing native currency and ERC20 tokens results in the expected TCL
     */
    function testgetTokenPriceInUsd() public {
        // Arrange
        uint256 amount = 1 ether;
        uint256 tokenId = 0;

        // Act
        vm.prank(USER);
        (bool success,) = address(deCup).call{value: amount}("");
        uint256 tcl = deCup.getTokenPriceInUsd(tokenId);

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
        uint256 tcl = (deCup.getTokenPriceInUsd(0) * 1e18) / 1e8; //50000 0000 0000
        uint256 usdcValue = deCup.getERC20UsdValue(address(s_mockTokenUsdc), depositUsdcAmount);

        // Assert
        assertEq(tcl, usdcValue); //50000 | 000 000 000 000 000 000
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
        (bool success,) = address(deCup).call{value: amount}("");
        address owner = deCup.ownerOf(tokenId);

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
        vm.prank(USER);
        (bool success,) = address(deCup).call{value: 1 ether}("");

        vm.prank(address(msg.sender));
        deCup.listForSale(tokenId);

        // Assert
        assert(success);
        assert(deCup.getIsListedForSale(tokenId));
    }

    /**
     * @notice Tests that the token is removed from sale
     * @dev Verifies that the token is removed from sale after removing
     */
    function testRemoveFromSale() public {
        // Arrange
        uint256 tokenId = 0;

        // Act
        vm.prank(USER);
        (bool success,) = address(deCup).call{value: 1 ether}("");

        vm.startPrank(address(msg.sender));
        deCup.listForSale(tokenId);
        deCup.removeFromSale(tokenId);
        vm.stopPrank();

        // Assert
        assert(success);
        assert(!deCup.getIsListedForSale(tokenId));
    }
}
