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
        "data:application/json;base64,eyJ0b2tlbklkIjoiMCIsIm5hbWUiOiJEZUN1cCMwICQxNTUwMDAiLCJkZXNjcmlwdGlvbiI6IkRlY2VudHJhbGl6ZWQgQ3VwIG9mIGFzc2V0cyIsICJhdHRyaWJ1dGVzIjogW3sidHJhaXRfdHlwZSI6IlRDTCIsInZhbHVlIjoiMTU1MDAwIFVTRCJ9LHsidHJhaXRfdHlwZSI6IkVUSCIsInZhbHVlIjoiMjAwMDAwMDAwMDAwMDAwMDAwMDAwMCJ9LHsidHJhaXRfdHlwZSI6IldFVEgiLCJ2YWx1ZSI6IjMwMDAwMDAwMDAwMDAwMDAwMDAwMDAifSx7InRyYWl0X3R5cGUiOiJXQlRDIiwidmFsdWUiOiIxMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAifSx7InRyYWl0X3R5cGUiOiJVU0RDIiwidmFsdWUiOiI1MDAwMDAwMDAwMDAwMDAwMDAwMDAwMCJ9XSwiaW1hZ2UiOiJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUIzYVdSMGFEMGlNVFUySWlCb1pXbG5hSFE5SWpFMU1DSWdkbWxsZDBKdmVEMGlNQ0F3SURFMU5pQXhOVEFpSUdacGJHdzlJbTV2Ym1VaUlIaHRiRzV6UFNKb2RIUndPaTh2ZDNkM0xuY3pMbTl5Wnk4eU1EQXdMM04yWnlJK0NqeHdZWFJvSUdROUlrMHhNakVnTXpCRE1UWXhJRFl3TGpNek16TWdNVFl4SURrd0xqWTJOamNnTVRJeElERXlNU0lnYzNSeWIydGxQU0lqTkRNNVFVWkZJaUJ6ZEhKdmEyVXRkMmxrZEdnOUlqRXdJaTgrQ2p4eVpXTjBJSGc5SWprMklpQjNhV1IwYUQwaU16SWlJR2hsYVdkb2REMGlNVFV3SWlCbWFXeHNQU0lqTkRNNVFVWkZJaTgrQ2p4eVpXTjBJSGc5SWpZMElpQjNhV1IwYUQwaU16SWlJR2hsYVdkb2REMGlNVFV3SWlCbWFXeHNQU0lqTkVWQk1VWkdJaTgrQ2p4eVpXTjBJSGc5SWpNeUlpQjNhV1IwYUQwaU16SWlJR2hsYVdkb2REMGlNVFV3SWlCbWFXeHNQU0lqTmpOQlEwWkdJaTgrQ2p4eVpXTjBJSGRwWkhSb1BTSXpNaUlnYUdWcFoyaDBQU0l4TlRBaUlHWnBiR3c5SWlNM09VSTRSa1lpTHo0S1BHY2dZMnhwY0Mxd1lYUm9QU0oxY213b0kyTnNhWEF3WHpSZk1qRTBLU0krQ2p4d1lYUm9JR1E5SWswMk15NDFJREV5Tmk0MU1rTTRPQzR3TnpZM0lERXlOaTQxTWlBeE1EZ2dNVEEyTGpBek15QXhNRGdnT0RBdU56WkRNVEE0SURVMUxqUTROelFnT0RndU1EYzJOeUF6TlNBMk15NDFJRE0xUXpNNExqa3lNek1nTXpVZ01Ua2dOVFV1TkRnM05DQXhPU0E0TUM0M05rTXhPU0F4TURZdU1ETXpJRE00TGpreU16TWdNVEkyTGpVeUlEWXpMalVnTVRJMkxqVXlXaUlnYzNSeWIydGxQU0ozYUdsMFpTSWdjM1J5YjJ0bExYZHBaSFJvUFNJeE1DSXZQZ284TDJjK0NqeG5JR05zYVhBdGNHRjBhRDBpZFhKc0tDTmpiR2x3TVY4MFh6SXhOQ2tpUGdvOGNHRjBhQ0JrUFNKTk5qTXVOU0F4TWpZdU5USkRPRGd1TURjMk55QXhNall1TlRJZ01UQTRJREV3Tmk0d016TWdNVEE0SURnd0xqYzJRekV3T0NBMU5TNDBPRGMwSURnNExqQTNOamNnTXpVZ05qTXVOU0F6TlVNek9DNDVNak16SURNMUlERTVJRFUxTGpRNE56UWdNVGtnT0RBdU56WkRNVGtnTVRBMkxqQXpNeUF6T0M0NU1qTXpJREV5Tmk0MU1pQTJNeTQxSURFeU5pNDFNbG9pSUhOMGNtOXJaVDBpSTBZMVJqQkdNQ0lnYzNSeWIydGxMWGRwWkhSb1BTSXhNQ0l2UGdvOGNHRjBhQ0JrUFNKTk5URWdOVGt1TWpaRE5USXVOalUyTXlBMU9TNHlOaUExTXk0NE1EY2dOVGt1Tmpjek5TQTFOQzQxTkRZNUlEWXdMalF4TXpORE5UVXVNamcyTmlBMk1TNHhOVE15SURVMUxqY3dNRElnTmpJdU16QTBJRFUxTGpjd01ESWdOak11T1RZd01sWTJOeTR4TWpZeVF6VTBMakkwTmpFZ05qWXVORE14TXlBMU1pNDJOREl6SURZMkxqQTFPVGdnTlRFZ05qWXVNRFU1T0VNME9DNHhNRGt6SURZMkxqQTFPVGdnTkRVdU16TTNNU0EyTnk0eU1EZ3pJRFF6TGpJNU15QTJPUzR5TlRJeVF6UXhMakkwT0RnZ056RXVNamsyTXlBME1DNHdPVGsySURjMExqQTJPVE1nTkRBdU1EazVOaUEzTmk0NU5qQXlRelF3TGpBNU9UY2dOemt1T0RVeElEUXhMakkwT0RrZ09ESXVOakl6TVNBME15NHlPVE1nT0RRdU5qWTNNa00wTlM0ek16Y3hJRGcyTGpjeE1UTWdORGd1TVRBNU1pQTROeTQ0TlRrMklEVXhJRGczTGpnMU9UWkROVEl1TmpReU5TQTROeTQ0TlRrMklEVTBMakkwTmlBNE55NDBPRGMwSURVMUxqY3dNRElnT0RZdU56a3lNbFk0T1M0NU5qQXlRelUxTGpjd01ESWdPVEV1TmpFMk1TQTFOUzR5T0RZMElEa3lMamMyTmpNZ05UUXVOVFEyT1NBNU15NDFNRFl4UXpVekxqZ3dOeUE1TkM0eU5EVTVJRFV5TGpZMU5qTWdPVFF1TmpZd05DQTFNU0E1TkM0Mk5qQTBTRE00TGpWV05Ua3VNalpJTlRGYVRUVTJMamN3TURJZ05qZ3VPRFk0TkVNMU55NHhOakExSURZNUxqRTVNallnTlRjdU5UazJOU0EyT1M0MU5UVTRJRFU0SURZNUxqazFPVEpETlRrdU9EVTJOaUEzTVM0NE1UVTRJRFl3TGprd01EUWdOelF1TXpNME5pQTJNQzQ1TURBMElEYzJMamsyTURKRE5qQXVPVEF3TXlBM09TNDFPRFU0SURVNUxqZzFOallnT0RJdU1UQXpOaUExT0NBNE15NDVOakF5UXpVM0xqVTVOallnT0RRdU16WXpOU0ExTnk0eE5qQXpJRGcwTGpjeU5Ua2dOVFl1TnpBd01pQTROUzR3TlZZMk9DNDROamcwV2swME1TNHdPVGsySURjMkxqazJNREpETkRFdU1EazVOaUEzTkM0ek16UTJJRFF5TGpFME16UWdOekV1T0RFMU9DQTBOQ0EyT1M0NU5Ua3lRelExTGpnMU5qWWdOamd1TVRBeU9TQTBPQzR6TnpRMUlEWTNMakExT1RnZ05URWdOamN1TURVNU9FTTFNaTQyTlRVNUlEWTNMakExT1RnZ05UUXVNalk0T0NBMk55NDBOelV5SURVMUxqY3dNRElnTmpndU1qUTNNMVk0TlM0Mk56RXhRelUwTGpJMk9EWWdPRFl1TkRRek5TQTFNaTQyTlRZeElEZzJMamcxT1RZZ05URWdPRFl1T0RVNU5rTTBPQzR6TnpRMElEZzJMamcxT1RZZ05EVXVPRFUyTmlBNE5TNDRNVFk0SURRMElEZ3pMamsyTURKRE5ESXVNVFF6TkNBNE1pNHhNRE0ySURReExqQTVPVGNnTnprdU5UZzFPQ0EwTVM0d09UazJJRGMyTGprMk1ESmFJaUJtYVd4c1BTSWpSalZHTUVZd0lpQnpkSEp2YTJVOUlpTkdOVVl3UmpBaUx6NEtQSEJoZEdnZ1pEMGlUVFUzTGpjMk1EUWdNVEF3TGpnMlNEY3dMakl6T1RoRE56RXVNVEF3TkNBeE1EQXVPRFlnTnpJdU1ESXhJREV3TVM0eU9EZ2dOek11TURBMk5DQXhNREl1TWpjelREYzRMak01TXpJZ01UQTNMalkyU0RRNUxqWXdOMHcxTkM0NU9UTTRJREV3TWk0eU56TkROVFV1T1RFM055QXhNREV1TXpRNUlEVTJMamM0TkRRZ01UQXdMamt4TlNBMU55NDFPVGd5SURFd01DNDROalZNTlRjdU56WXdOQ0F4TURBdU9EWmFJaUJtYVd4c1BTSWpSalZHTUVZd0lpQnpkSEp2YTJVOUlpTkdOVVl3UmpBaUx6NEtQQzluUGdvOFp5QmpiR2x3TFhCaGRHZzlJblZ5YkNnalkyeHBjREpmTkY4eU1UUXBJajRLUEhCaGRHZ2daRDBpVFRZMUxqVWdNVEkyTGpVeVF6a3dMakEzTmpjZ01USTJMalV5SURFeE1DQXhNRFl1TURNeklERXhNQ0E0TUM0M05rTXhNVEFnTlRVdU5EZzNOQ0E1TUM0d056WTNJRE0xSURZMUxqVWdNelZETkRBdU9USXpNeUF6TlNBeU1TQTFOUzQwT0RjMElESXhJRGd3TGpjMlF6SXhJREV3Tmk0d016TWdOREF1T1RJek15QXhNall1TlRJZ05qVXVOU0F4TWpZdU5USmFJaUJ6ZEhKdmEyVTlJaU5GUWtWQlJVRWlJSE4wY205clpTMTNhV1IwYUQwaU1UQWlMejRLUEhCaGRHZ2daRDBpVFRZNExqWWdOVGd1TnpaRE56VXVOVE16TXlBMU9DNDNOaUE0TUM0M016TXpJRFl4TGpNMklEZzBMaklnTmpZdU5UWkRPRGN1TmpZMk55QTNNUzQzTmlBNE9TNDBJRGMyTGprMklEZzVMalFnT0RJdU1UWkRPRFV1T1RNek15QTVNQzQ0TWpZM0lEYzVMamcyTmpjZ09UVXVNVFlnTnpFdU1pQTVOUzR4TmtnMk5sWTROeTR6TmtnM01TNHlRemMwTGpZMk5qY2dPRGN1TXpZZ056Y3VNalkyTnlBNE5TNDJNalkzSURjNUlEZ3lMakUyUXpjM0xqSTJOamNnTnpndU5qa3pNeUEzTkM0Mk5qWTNJRGMyTGprMklEY3hMaklnTnpZdU9UWklOalpXTlRndU56WklOamd1TmxvaUlHWnBiR3c5SWlORlFrVkJSVUVpTHo0S1BIQmhkR2dnWkQwaVRUVTVMamMySURFd01DNHpOa2czTWk0eU5FTTNNeTR5T0NBeE1EQXVNellnTnpRdU16SWdNVEF3TGpnNElEYzFMak0ySURFd01TNDVNa3c0TVM0MklERXdPQzR4TmtnMU1DNDBURFUyTGpZMElERXdNUzQ1TWtNMU55NDJPQ0F4TURBdU9EZ2dOVGd1TnpJZ01UQXdMak0ySURVNUxqYzJJREV3TUM0ek5sb2lJR1pwYkd3OUlpTkZRa1ZCUlVFaUx6NEtQQzluUGdvOFp5QmpiR2x3TFhCaGRHZzlJblZ5YkNnalkyeHBjRE5mTkY4eU1UUXBJajRLUEhCaGRHZ2daRDBpVFRZMUxqVWdNVEkyTGpVeVF6a3dMakEzTmpjZ01USTJMalV5SURFeE1DQXhNRFl1TURNeklERXhNQ0E0TUM0M05rTXhNVEFnTlRVdU5EZzNOQ0E1TUM0d056WTNJRE0xSURZMUxqVWdNelZETkRBdU9USXpNeUF6TlNBeU1TQTFOUzQwT0RjMElESXhJRGd3TGpjMlF6SXhJREV3Tmk0d016TWdOREF1T1RJek15QXhNall1TlRJZ05qVXVOU0F4TWpZdU5USmFJaUJ6ZEhKdmEyVTlJaU5GTUVSR1JFWWlJSE4wY205clpTMTNhV1IwYUQwaU1UQWlMejRLUEM5blBnbzhaR1ZtY3o0S1BHTnNhWEJRWVhSb0lHbGtQU0pqYkdsd01GODBYekl4TkNJK0NqeHlaV04wSUhkcFpIUm9QU0l6TWlJZ2FHVnBaMmgwUFNJeE1qZ2lJR1pwYkd3OUluZG9hWFJsSWlCMGNtRnVjMlp2Y20wOUluUnlZVzV6YkdGMFpTZ3dJREUzS1NJdlBnbzhMMk5zYVhCUVlYUm9QZ284WTJ4cGNGQmhkR2dnYVdROUltTnNhWEF4WHpSZk1qRTBJajRLUEhKbFkzUWdkMmxrZEdnOUlqTXlJaUJvWldsbmFIUTlJakV5T0NJZ1ptbHNiRDBpZDJocGRHVWlJSFJ5WVc1elptOXliVDBpZEhKaGJuTnNZWFJsS0RNeUlERTNLU0l2UGdvOEwyTnNhWEJRWVhSb1BnbzhZMnhwY0ZCaGRHZ2dhV1E5SW1Oc2FYQXlYelJmTWpFMElqNEtQSEpsWTNRZ2QybGtkR2c5SWpNeUlpQm9aV2xuYUhROUlqRXlPQ0lnWm1sc2JEMGlkMmhwZEdVaUlIUnlZVzV6Wm05eWJUMGlkSEpoYm5Oc1lYUmxLRFkwSURFM0tTSXZQZ284TDJOc2FYQlFZWFJvUGdvOFkyeHBjRkJoZEdnZ2FXUTlJbU5zYVhBelh6UmZNakUwSWo0S1BISmxZM1FnZDJsa2RHZzlJak15SWlCb1pXbG5hSFE5SWpFeU9DSWdabWxzYkQwaWQyaHBkR1VpSUhSeVlXNXpabTl5YlQwaWRISmhibk5zWVhSbEtEazJJREUzS1NJdlBnbzhMMk5zYVhCUVlYUm9QZ284TDJSbFpuTStDand2YzNablBnbz0ifQ==";

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
    function testWithdrawNativeCurrency() public {
        // Arrange
        uint256 initialBalance = USER.balance;

        // First deposit 1 ether to get an NFT
        vm.prank(USER);
        (bool success,) = address(s_deCup).call{value: 1 ether}("");
        assert(success);

        uint256 tokenId = 0; // First minted token will have ID 0

        // Act - Burn the NFT to withdraw the collateral
        vm.prank(USER);
        s_deCup.burn(tokenId);

        // Assert
        assertEq(USER.balance, initialBalance); // User should get back their 1 ether
        assertEq(address(s_deCup).balance, 0); // Contract should have no balance
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
        // Act - First deposit to mint NFT, then burn to withdraw
        vm.startPrank(USER);
        IERC20Metadata(s_mockTokenUsdc).approve(address(s_deCup), depositUsdcAmount);

        console.log(IERC20Metadata(s_mockTokenUsdc).balanceOf(USER));

        s_deCup.depositSingleAssetAndMint(address(s_mockTokenUsdc), depositUsdcAmount);
        vm.stopPrank();
        _;
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
        vm.startPrank(USER);
        s_deCup.addTokenCollateralToExistingCup(address(s_mockTokenUsdc), 1 ether, 0);
        vm.stopPrank();
        uint256 afterBalance = s_deCup.getCollateralDeposited(0, address(s_mockTokenUsdc));
        assertEq(afterBalance, initialBalance + 1 ether);
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
        uint256 tokenId = 0; // First minted token will have ID 0
        s_deCup.burn(tokenId); // Burn NFT to withdraw all collateral
        vm.stopPrank();

        // Assert
        assertEq(IERC20Metadata(s_mockTokenWeth).balanceOf(address(s_deCup)), 0);
        assertEq(IERC20Metadata(s_mockTokenWbtc).balanceOf(address(s_deCup)), 0);
        assertEq(IERC20Metadata(s_mockTokenUsdc).balanceOf(address(s_deCup)), 0);
        assertEq(address(s_deCup).balance, 0);
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
}
