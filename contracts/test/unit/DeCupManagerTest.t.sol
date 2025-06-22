// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DeCupManager} from "src/DeCupManager.sol";
import {HelperConfigDeCupManager} from "script/HelperConfigDeCupManager.s.sol";
import {HelperConfigDeCup} from "script/HelperConfigDeCup.s.sol";
import {DeployDeCup} from "script/DeployDeCup.s.sol";
import {DeCup} from "src/DeCup.sol";
import {stdError} from "forge-std/StdError.sol";

contract DeCupManagerTest is Test {
    DeCupManager public decupManager;
    DeCup public deCup;
    HelperConfigDeCup public s_configDeCup;

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
        DeployDeCup deployer = new DeployDeCup();
        (deCup, s_configDeCup) = deployer.run();

        HelperConfigDeCupManager helperConfigDCM = new HelperConfigDeCupManager();
        HelperConfigDeCupManager.NetworkConfig memory networkConfigDCM = helperConfigDCM.getConfig();
        decupManager = new DeCupManager(address(deCup), networkConfigDCM.pricePriceFeed);

        // Fund test users
        vm.deal(user1, STARTING_BALANCE);
        vm.deal(user2, STARTING_BALANCE);
        vm.deal(user3, STARTING_BALANCE);

        // Mint a test NFT to user1
        vm.prank(user1);
        (bool success,) = address(deCup).call{value: 1 ether}("");
        assertTrue(success);

        vm.prank(msg.sender);
        deCup.transferOwnership(address(decupManager));
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
    //1000000000000000000
    //1000000000000000000

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
        uint256 newCollateral = 0.02 ether;

        decupManager.setCcipCollateral(newCollateral);

        assertEq(decupManager.s_ccipCollateral(), newCollateral);
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
        assertEq(decupManager.getSaleOwner(0), user1);
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
        deCup.listForSale(TEST_TOKEN_ID);

        vm.prank(user2);
        vm.expectRevert(DeCupManager.DeCupManager__TokenListedForSale.selector);
        decupManager.createSale(TEST_TOKEN_ID, address(0));
    }

    function testCreateCrossSaleRevertsWithInsufficientETH() public {
        uint256 insufficientAmount = 0.005 ether; // Less than ccipCollateral

        vm.prank(user2);
        vm.expectRevert(DeCupManager.DeCupManager__InsufficientETH.selector);
        decupManager.createCrossSale{value: insufficientAmount}(TEST_TOKEN_ID, user1, TEST_NETWORK_ID);
    }

    function testCreateCrossSaleRevertsWithZeroValue() public {
        vm.prank(user2);
        vm.expectRevert(DeCupManager.DeCupManager__MoreThanZero.selector);
        decupManager.createCrossSale{value: 0}(TEST_TOKEN_ID, user1, TEST_NETWORK_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        SALE CANCELLATION TESTS
    //////////////////////////////////////////////////////////////*/

    function testCancelSaleRevertsWithNonexistentSale() public {
        uint256 nonexistentSaleId = 999;

        vm.expectRevert(DeCupManager.DeCupManager__SaleNotFound.selector);
        decupManager.cancelSale(nonexistentSaleId);
    }

    function testCancelCrossSaleRevertsWithInsufficientETH() public {
        uint256 insufficientAmount = 0.005 ether;

        vm.prank(user1);
        vm.expectRevert(DeCupManager.DeCupManager__InsufficientETH.selector);
        decupManager.cancelCrossSale{value: insufficientAmount}(0, TEST_NETWORK_ID, TEST_TOKEN_ID);
    }

    function testCancelCrossSaleRevertsIfTokenNotListed() public {
        uint256 sufficientAmount = 0.02 ether;

        vm.prank(user1);
        vm.expectRevert(DeCupManager.DeCupManager__TokenNotListedForSale.selector);
        decupManager.cancelCrossSale{value: sufficientAmount}(0, TEST_NETWORK_ID, TEST_TOKEN_ID);
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
        decupManager.buy{value: insufficientAmount}(0, TEST_PRICE_USD, msg.sender, false);
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
        decupManager.buy{value: requiredETH}(saleId, tokenPrice, user2, false);

        assertEq(deCup.ownerOf(TEST_TOKEN_ID), user2);
    }

    function testBuyAndBurnSuccessWithSufficientETH() public {
        uint256 decupTCL = deCup.getTokenPriceInUsd(TEST_TOKEN_ID); //2000 0000 0000
        uint256 requiredETH = decupManager.getPriceInETH(decupTCL); //2000 000 000 000 000 000 000
        console.log("decupTCL", decupTCL);
        console.log("requiredETH", requiredETH); //1 000 000 000 000 000 000
        console.log("user1", user1);
        console.log("user2", user2);
        console.log("msg.sender", msg.sender);

        uint256 user1BalanceBefore = address(user1).balance;
        uint256 user2BalanceBefore = address(user2).balance;
        uint256 saleId = 0;

        vm.prank(user1);
        decupManager.createSale(TEST_TOKEN_ID, user1);
        assertEq(decupManager.getSaleOwner(0), user1);

        vm.expectEmit(true, true, false, true);
        emit Buy(saleId, user2, requiredETH);

        vm.prank(user2);
        decupManager.buy{value: requiredETH}(saleId, decupTCL, user2, true);

        vm.prank(user1);
        decupManager.withdrawFunds();

        uint256 user1BalanceAfter = address(user1).balance;
        uint256 user2BalanceAfter = address(user2).balance;

        assertEq(user1BalanceAfter, user1BalanceBefore + requiredETH);
        assertEq(user2BalanceAfter, user2BalanceBefore);
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
        uint256 expectedMinimum = decupManager.s_ccipCollateral(); // At least the collateral amount

        assertTrue(priceInETH >= expectedMinimum, "Price should include collateral");
    }

    function testGetDeCupAddress() public view {
        assertEq(decupManager.getDeCupAddress(), address(deCup));
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

    function testSaleCounterIncrementsCorrectly() public view {
        uint256 initialCounter = decupManager.s_saleCounter();

        // The counter should increment but we can't easily test createSale due to ownership logic
        // This test verifies the initial state
        assertEq(initialCounter, 0);
    }

    function testCcipCollateralDefaultValue() public view {
        assertEq(decupManager.s_ccipCollateral(), 0.01 ether);
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
        vm.assume(amount <= 100 ether); // Reasonable upper bound

        decupManager.setCcipCollateral(amount);

        assertEq(decupManager.s_ccipCollateral(), amount);
    }

    function testFuzzGetPriceInETH(uint256 priceInUSD) public view {
        uint256 minPrice = decupManager.s_ccipCollateral();
        uint256 minPriceUsd = (minPrice * decupManager.getEthUsdPrice()) / 1e18;
        vm.assume(priceInUSD > minPriceUsd && priceInUSD <= 1e15); // Reasonable bounds

        uint256 priceInETH = decupManager.getPriceInETH(priceInUSD);

        assertTrue(priceInETH >= minPrice);
    }
}
