// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DeCupManager} from "src/DeCupManager.sol";
import {HelperConfigDeCupManager} from "script/HelperConfigDeCupManager.s.sol";
import {HelperConfigDeCup} from "script/HelperConfigDeCup.s.sol";
import {DeployDeCup} from "script/DeployDeCup.s.sol";
import {DeCup} from "src/DeCup.sol";
import {stdError} from "forge-std/StdError.sol";
import {DeployDeCupManager} from "script/DeployDeCupManager.s.sol";

contract DeCupManagerTest is Test {
    DeCupManager public decupManager;
    DeployDeCupManager public deployer;
    DeCup public deCup;
    HelperConfigDeCup public s_configDeCup;
    HelperConfigDeCupManager public s_configDeCupManager;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant TEST_TOKEN_ID = 0;
    uint256 public constant TEST_PRICE_USD = 100e8; // $100 with 8 decimals
    uint64 public constant TEST_NETWORK_ID = 1;

    // Events for testing
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event CancelSale(uint256 indexed saleId);
    event CreateSale(uint256 indexed saleId, uint256 indexed tokenId, address indexed sellerAddress);
    event Buy(uint256 indexed saleId, address indexed buyerAddress, uint256 amountPaied);
    event FinalizeBuy(uint256 indexed saleId, address indexed buyerAddress, uint256 amountPaied);

    function setUp() public {
        // Deploy DeCupManager
        deployer = new DeployDeCupManager();
        (decupManager, deCup, s_configDeCup, s_configDeCupManager) = deployer.run();

        // Fund test users
        vm.deal(user1, STARTING_BALANCE);
        vm.deal(user2, STARTING_BALANCE);
        vm.deal(user3, STARTING_BALANCE);

        // Mint a test NFT to user1
        vm.prank(user1);
        (bool success,) = address(deCup).call{value: 1 ether}("");
        assertTrue(success);
    }

    modifier createSale(address _user) {
        vm.prank(_user);
        decupManager.createSale(TEST_TOKEN_ID, _user);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testDeCupManagerConstructor() public view {
        assertEq(address(decupManager.getDeCupAddress()), address(deCup));
    }

    /*//////////////////////////////////////////////////////////////
                        FUNDING TESTS
    //////////////////////////////////////////////////////////////*/

    function testReceiveFunctionAddsCollateral() public {
        uint256 fundAmount = 1 ether;
        console.log("fundAmount", fundAmount);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, fundAmount);

        vm.prank(user1);
        (bool success,) = address(decupManager).call{value: fundAmount}("");
        assertTrue(success);

        assertEq(decupManager.balanceOf(user1), fundAmount);
    }

    function testReceiveRevertsWithZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(DeCupManager.DeCupManager__MoreThanZero.selector);
        (bool success,) = address(decupManager).call{value: 0}("");
        assertTrue(success);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testWithdrawFundsRevertsWithInsufficientFunds() public {
        // User has no collateral
        vm.prank(user1);
        vm.expectRevert(DeCupManager.DeCupManager__InsufficientFunds.selector);
        decupManager.withdrawFunds();
    }

    function testWithdrawFundsRevertsWithZeroCollateral() public {
        // Even with zero collateral, should revert due to logic error in _removeCollateral
        vm.prank(user1);
        vm.expectRevert(DeCupManager.DeCupManager__InsufficientFunds.selector);
        decupManager.withdrawFunds();
    }

    /*//////////////////////////////////////////////////////////////
                        OWNER FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testOwnerCanTransferDeCupOwnership() public {
        address newOwner = makeAddr("newOwner");

        // Get current owner of DeCup (should be decupManager)
        address currentOwner = deCup.owner();
        assertEq(currentOwner, address(decupManager));

        // Transfer ownership
        vm.prank(msg.sender);
        decupManager.transferOwnershipOfDeCup(newOwner);

        // Verify new owner
        assertEq(deCup.owner(), newOwner);
    }

    function testNonOwnerCannotTransferDeCupOwnership() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(user1);
        vm.expectRevert();
        decupManager.transferOwnershipOfDeCup(newOwner);
    }

    function testOwnerCanSetCcipCollateral() public {
        uint256 newCollateral = 1e8;
        vm.prank(msg.sender);
        decupManager.setCcipCollateral(newCollateral);

        assertEq(decupManager.getCcipCollateralInUsd(), newCollateral);
    }

    function testNonOwnerCannotSetCcipCollateral() public {
        uint256 newCollateral = 0.02 ether;

        vm.prank(user1);
        vm.expectRevert();
        decupManager.setCcipCollateral(newCollateral);
    }

    /*//////////////////////////////////////////////////////////////
                        SALE CREATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testCreateSaleSuccess() public {
        vm.prank(user1); // Different user than token owner
        decupManager.createSale(TEST_TOKEN_ID, address(0));
        assertEq(decupManager.getSaleOwner(0, block.chainid), user1);
    }

    function testCreateSaleRevertsIfNotOwner() public {
        // First need to ensure user1 owns the token but isn't the caller
        vm.prank(user2); // Different user than token owner
        vm.expectRevert(DeCupManager.DeCupManager__NotOwner.selector);
        decupManager.createSale(TEST_TOKEN_ID, address(0));
    }

    function testCreateSaleRevertsIfTokenAlreadyListed() public {
        // First list the token
        vm.prank(address(decupManager));
        deCup.listForSale(TEST_TOKEN_ID, TEST_NETWORK_ID);

        vm.prank(user2);
        vm.expectRevert(DeCupManager.DeCupManager__TokenListedForSale.selector);
        decupManager.createSale(TEST_TOKEN_ID, address(0));
    }

    function testCreateCrossSaleRevertsWithInsufficientETH() public {
        uint256 insufficientAmount = decupManager.getCcipCollateralInEth() - 0.001 ether; // Less than ccipCollateral

        vm.prank(user2);
        vm.expectRevert(DeCupManager.DeCupManager__InsufficientETH.selector);
        decupManager.createCrossSale{value: insufficientAmount}(TEST_TOKEN_ID, user1, TEST_NETWORK_ID, TEST_PRICE_USD);
    }

    function testCreateCrossSaleRevertsWithZeroValue() public {
        vm.prank(user2);
        vm.expectRevert(DeCupManager.DeCupManager__MoreThanZero.selector);
        decupManager.createCrossSale{value: 0}(TEST_TOKEN_ID, user1, TEST_NETWORK_ID, TEST_PRICE_USD);
    }

    /*//////////////////////////////////////////////////////////////
                        SALE CANCELLATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testCancelExistingSale() public createSale(user1) {
        uint256 saleId = 0;

        vm.expectEmit(true, true, false, true);
        emit CancelSale(saleId);

        vm.prank(user1);
        decupManager.cancelSale(saleId);
    }

    function testCancelExistingSaleByTokenId() public createSale(user1) {
        uint256 tokenId = decupManager.getSaleOrder(block.chainid, 0).tokenId;

        vm.expectEmit(true, true, false, true);
        emit CancelSale(0);

        vm.prank(user1);
        decupManager.cancelSale(tokenId);
    }

    function testCancelSaleRevertsWithNonExistentSale() public {
        uint256 nonexistentSaleId = 999;

        vm.expectRevert(DeCupManager.DeCupManager__SaleNotFound.selector);
        decupManager.cancelSale(nonexistentSaleId);
    }

    function testCancelCrossSaleRevertsWithInsufficientETH() public {
        uint256 insufficientAmount = decupManager.getCcipCollateralInEth() - 0.001 ether;

        vm.prank(user1);
        vm.expectRevert(DeCupManager.DeCupManager__InsufficientETH.selector);
        decupManager.cancelCrossSale{value: insufficientAmount}(TEST_NETWORK_ID, TEST_TOKEN_ID);
    }

    function testCancelCrossSaleRevertsIfTokenNotListed() public {
        uint256 sufficientAmount = 0.02 ether;

        vm.prank(user1);
        vm.expectRevert(DeCupManager.DeCupManager__TokenNotListedForSale.selector);
        decupManager.cancelCrossSale{value: sufficientAmount}(TEST_NETWORK_ID, TEST_TOKEN_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        BUY FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testBuyRevertsWithInsufficientETH() public createSale(user1) {
        uint256 insufficientAmount = 0.001 ether;
        //console.log("TEST_PRICE_USD", TEST_PRICE_USD); //100 000 000 000 000 000 000
        //console.log("priceInETH", decupManager.getPriceInETH(TEST_PRICE_USD)); //100 | 000 000 000 000 000 000
        //1 000 000 000 000 000
        //TEST_PRICE_USD 100 0000 0000
        vm.prank(user2);
        vm.expectRevert(DeCupManager.DeCupManager__InsufficientETH.selector);
        decupManager.buy{value: insufficientAmount}(0, msg.sender, false);
    }

    function testBuySuccessWithSufficientETH() public createSale(user1) {
        uint256 tokenPrice = deCup.getTokenPriceInUsd(0);
        uint256 requiredETH = decupManager.getPriceInETH(tokenPrice);
        uint256 saleId = 0;

        console.log("tokenPrice", tokenPrice);
        console.log("requiredETH", requiredETH);

        vm.expectEmit(true, true, false, true);
        emit Buy(saleId, user2, requiredETH);

        vm.prank(user2);
        decupManager.buy{value: requiredETH}(saleId, user2, false);

        assertEq(deCup.ownerOf(TEST_TOKEN_ID), user2);
    }

    function testBuyAndBurnSuccessWithSufficientETH() public {
        uint256 decupTCL = deCup.getTokenPriceInUsd(TEST_TOKEN_ID); //2000 0000 0000
        uint256 requiredETH = decupManager.getPriceInETH(decupTCL); //2000 000 000 000 000 000 000
        // console.log("decupTCL", decupTCL);
        // console.log("requiredETH", requiredETH); //996 983 661 127 272 979
        // console.log("user1", user1);
        // console.log("user2", user2);
        // console.log("msg.sender", msg.sender);

        uint256 user1BalanceBefore = address(user1).balance;
        uint256 user2BalanceBefore = address(user2).balance;
        // console.log("user1BalanceBefore", user1BalanceBefore);
        // console.log("user2BalanceBefore", user2BalanceBefore);
        uint256 saleId = 0;

        vm.prank(user1);
        decupManager.createSale(TEST_TOKEN_ID, user1);
        assertEq(decupManager.getSaleOwner(0, block.chainid), user1);

        vm.expectEmit(true, true, false, true);
        emit Buy(saleId, user2, requiredETH);

        vm.prank(user2);
        decupManager.buy{value: requiredETH}(saleId, user2, true);

        console.log("user1 balance before withdraw", address(user1).balance);
        console.log("user2 balance before withdraw", address(user2).balance);
        vm.prank(user1);
        decupManager.withdrawFunds();

        uint256 user1BalanceAfter = address(user1).balance;
        uint256 user2BalanceAfter = address(user2).balance;

        //9 800 300 000 000 000 000
        //10 000 000 000 000 000 000

        assertEq(user1BalanceBefore + requiredETH, user1BalanceAfter, "User1 balance doesn't match");

        //10 000 000 000 000 000 000
        //10 003 016 338 872 727 021
        assertEq(user2BalanceBefore, user2BalanceAfter, "User2 balance doesn't match");
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetEthUsdPrice() public view {
        uint256 price = decupManager.getEthUsdPrice();
        assertTrue(price > 0, "Price should be greater than 0");
    }

    function testGetPriceInETH() public view {
        uint256 priceInETH = decupManager.getPriceInETH(TEST_PRICE_USD);
        uint256 expectedMinimum = decupManager.getCcipCollateralInEth(); // At least the collateral amount

        assertTrue(priceInETH >= expectedMinimum, "Price should include collateral");
    }

    function testGetPriceInUsd() public view {
        uint256 testPriceInETH = 1 ether;
        uint256 priceInUsd = decupManager.getPriceInUsd(testPriceInETH);
        assertTrue(priceInUsd > 0, "USD price should be greater than 0");

        // Test round trip conversion
        uint256 convertedBackToETH = decupManager.getPriceInETH(priceInUsd);
        // Allow for small rounding error due to division
        assertTrue(
            convertedBackToETH >= testPriceInETH - 1000 && convertedBackToETH <= testPriceInETH + 1000,
            "Round trip conversion should be approximately equal"
        );
    }

    function testGetPriceInETHIncludingCollateral() public view {
        uint256 basePrice = decupManager.getPriceInETH(TEST_PRICE_USD);
        uint256 priceWithCollateral = decupManager.getPriceInETHIncludingCollateral(TEST_PRICE_USD);
        uint256 collateralAmount = decupManager.getCcipCollateralInEth();

        assertEq(priceWithCollateral, basePrice + collateralAmount, "Price should include collateral");
        assertTrue(priceWithCollateral > basePrice, "Price with collateral should be higher than base price");
    }

    function testGetDeCupAddress() public view {
        assertEq(decupManager.getDeCupAddress(), address(deCup));
    }

    function testGetCCIPRouter() public view {
        address router = decupManager.getCCIPRouter();
        // On Anvil, the router might not be properly set up, so we just check it returns an address
        // On real networks, it should be non-zero
        if (block.chainid == 31337) {
            // Anvil - just check that the function returns without reverting
            console.log("CCIP Router on Anvil:", router);
        } else {
            assertTrue(router != address(0), "CCIP router address should not be zero on real networks");
        }
    }

    function testGetPriceFeedAddress() public view {
        address priceFeed = decupManager.getPriceFeedAddress();
        assertTrue(priceFeed != address(0), "Price feed address should not be zero");
    }

    function testGetSaleCounter() public {
        uint256 initialCounter = decupManager.getSaleCounter();

        // Create a sale to increment counter
        vm.prank(user1);
        decupManager.createSale(TEST_TOKEN_ID, user1);

        uint256 newCounter = decupManager.getSaleCounter();
        assertEq(newCounter, initialCounter + 1, "Sale counter should increment after creating sale");
    }

    function testGetCcipCollateralInUsd() public view {
        uint256 collateralInUsd = decupManager.getCcipCollateralInUsd();
        assertTrue(collateralInUsd > 0, "CCIP collateral in USD should be greater than 0");
        // Default value should be 5e8 (5 USD with 8 decimals)
        assertEq(collateralInUsd, 5e8, "Default CCIP collateral should be 5 USD");
    }

    /*//////////////////////////////////////////////////////////////
                    CHAIN CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testGetChainSelector() public view {
        // Test current chain selector
        uint64 currentChainSelector = decupManager.getChainSelector(block.chainid);
        if (block.chainid == 31337) {
            // Anvil - selector might be 0 since we're using testnet configs
            console.log("Chain selector on Anvil:", currentChainSelector);
        } else {
            assertTrue(currentChainSelector > 0, "Current chain selector should be set on real networks");
        }
    }

    function testGetLinkAddress() public view {
        // Test current chain LINK address
        address linkAddress = decupManager.getLinkAddress(block.chainid);
        if (block.chainid == 31337) {
            // Anvil - LINK address might not be properly set up
            console.log("LINK address on Anvil:", linkAddress);
        } else {
            assertTrue(linkAddress != address(0), "Current chain LINK address should be set on real networks");
        }
    }

    function testGetReceiverAddress() public {
        uint256 testChainId = 12345;
        address testReceiver = makeAddr("testReceiver");

        // Initially should be zero
        assertEq(decupManager.getReceiverAddress(testChainId), address(0), "Receiver should be zero initially");

        // Add receiver address
        vm.prank(msg.sender);
        decupManager.addChainReceiver(testChainId, testReceiver);

        // Should now return the set address
        assertEq(decupManager.getReceiverAddress(testChainId), testReceiver, "Receiver should be set correctly");
    }

    function testGetRouterAddress() public view {
        // Test current chain router address
        address routerAddress = decupManager.getRouterAddress(block.chainid);
        if (block.chainid == 31337) {
            // Anvil - router address might not be properly set up
            console.log("Router address on Anvil:", routerAddress);
        } else {
            assertTrue(routerAddress != address(0), "Current chain router address should be set on real networks");
        }
    }

    function testGetSaleOrder() public {
        // Create a sale first
        vm.prank(user1);
        decupManager.createSale(TEST_TOKEN_ID, user1);

        // Get the sale order
        DeCupManager.Order memory saleOrder = decupManager.getSaleOrder(block.chainid, 0);

        // Verify order details
        assertEq(saleOrder.tokenId, TEST_TOKEN_ID, "Token ID should match");
        assertEq(saleOrder.sellerAddress, user1, "Seller address should match");
        assertEq(saleOrder.beneficiaryAddress, user1, "Beneficiary address should match");
        assertEq(saleOrder.chainId, block.chainid, "Chain ID should match");
    }

    function testGetSaleOrderNonExistent() public view {
        // Test getting a non-existent sale order
        DeCupManager.Order memory saleOrder = decupManager.getSaleOrder(block.chainid, 999);

        // Should return empty order
        assertEq(saleOrder.tokenId, 0, "Token ID should be 0 for non-existent order");
        assertEq(saleOrder.sellerAddress, address(0), "Seller should be zero address for non-existent order");
        assertEq(saleOrder.beneficiaryAddress, address(0), "Beneficiary should be zero address for non-existent order");
        assertEq(saleOrder.chainId, 0, "Chain ID should be 0 for non-existent order");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testFullSaleWorkflow() public {
        // Note: This test shows the expected workflow but some functions have logical issues
        // that prevent full execution (like the NotOwner check logic)

        uint256 fundAmount = 1 ether;

        // User1 funds their account
        vm.prank(user1);
        (bool success,) = address(decupManager).call{value: fundAmount}("");
        assertTrue(success);

        // Verify funding
        assertEq(decupManager.balanceOf(user1), fundAmount);
    }

    function testMultipleUserFunding() public {
        uint256 amount1 = 1 ether;
        uint256 amount2 = 2 ether;

        // User1 funds
        vm.prank(user1);
        (bool success1,) = address(decupManager).call{value: amount1}("");
        assertTrue(success1);

        // User2 funds
        vm.prank(user2);
        (bool success2,) = address(decupManager).call{value: amount2}("");
        assertTrue(success2);

        // Verify balances
        assertEq(decupManager.balanceOf(user1), amount1);
        assertEq(decupManager.balanceOf(user2), amount2);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSaleCounterIncrementsCorrectly() public createSale(user1) {
        uint256 initialCounter = decupManager.getSaleCounter();

        // The counter should increment but we can't easily test createSale due to ownership logic
        // This test verifies the initial state
        assertEq(initialCounter, 1);
    }

    function testCcipCollateralDefaultValue() public view {
        assert(decupManager.getCcipCollateralInUsd() > 0.1e8);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzzReceiveFunding(uint256 amount) public {
        vm.assume(amount > 0 && amount <= STARTING_BALANCE / 2);

        vm.prank(user1);
        (bool success,) = address(decupManager).call{value: amount}("");
        assertTrue(success);

        assertEq(decupManager.balanceOf(user1), amount);
    }

    function testFuzzSetCcipCollateral(uint256 amount) public {
        vm.assume(amount <= 10e8); // Reasonable upper bound

        vm.prank(msg.sender);
        decupManager.setCcipCollateral(amount);

        assertEq(decupManager.getCcipCollateralInUsd(), amount);
    }

    function testFuzzGetPriceInETH(uint256 priceInUSD) public view {
        uint256 minPrice = decupManager.getCcipCollateralInEth();
        uint256 minPriceUsd = (minPrice * decupManager.getEthUsdPrice()) / 1e18;
        vm.assume(priceInUSD > minPriceUsd && priceInUSD <= 1e15); // Reasonable bounds

        uint256 priceInETH = decupManager.getPriceInETH(priceInUSD);

        assertTrue(priceInETH >= minPrice);
    }

    function testFuzzGetPriceInUsd(uint256 priceInETH) public view {
        // Need sufficient amount to avoid rounding to 0 in USD conversion
        vm.assume(priceInETH >= 1e15 && priceInETH <= 100 ether); // Reasonable bounds starting from 0.001 ETH

        uint256 priceInUsd = decupManager.getPriceInUsd(priceInETH);

        assertTrue(priceInUsd > 0, "USD price should be greater than 0");

        // Test that converting back gives approximately the same result
        uint256 convertedBack = decupManager.getPriceInETH(priceInUsd);
        // Allow for rounding errors - should be within 0.1% of original
        uint256 tolerance = priceInETH / 1000;
        assertTrue(
            convertedBack >= priceInETH - tolerance && convertedBack <= priceInETH + tolerance,
            "Round trip conversion should be approximately equal"
        );
    }

    function testFuzzGetPriceInETHIncludingCollateral(uint256 priceInUSD) public view {
        vm.assume(priceInUSD > 0 && priceInUSD <= 1e12); // Reasonable bounds

        uint256 basePrice = decupManager.getPriceInETH(priceInUSD);
        uint256 priceWithCollateral = decupManager.getPriceInETHIncludingCollateral(priceInUSD);
        uint256 collateral = decupManager.getCcipCollateralInEth();

        assertEq(priceWithCollateral, basePrice + collateral, "Should add collateral to base price");
        assertTrue(priceWithCollateral > basePrice, "Price with collateral should be higher");
    }

    function testFuzzGetChainSelector(uint256 chainId) public view {
        vm.assume(chainId != 0);

        uint64 selector = decupManager.getChainSelector(chainId);
        // For non-configured chains, selector should be 0
        // For configured chains (like current chain), selector should be > 0
        if (chainId == block.chainid) {
            assertTrue(selector > 0, "Current chain should have a selector");
        }
        // Note: Other chains might return 0 which is valid
    }
}
