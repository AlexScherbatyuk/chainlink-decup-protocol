// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DeCup} from "src/DeCup.sol";
import {DeCupManager} from "src/DeCupManager.sol";
import {DeployDeCup} from "script/DeployDeCup.s.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {HelperConfigDeCup} from "script/HelperConfigDeCup.s.sol";
import {HelperConfigDeCupManager} from "script/HelperConfigDeCupManager.s.sol";

contract CCIPInteractionsTest is Test {
    HelperConfigDeCup public helperConfigDeCup;
    HelperConfigDeCupManager public helperConfigDeCupManager;

    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint256 ethSepoliaFork;
    uint256 avlFujiFork;
    Register.NetworkDetails ethSepoliaNetworkDetails;
    Register.NetworkDetails avlFujiNetworkDetails;

    DeCup public ethSepoliaDeCup;
    DeCup public avlFujiDeCup;

    DeCupManager public ethSepoliaDeCupManager;
    DeCupManager public avlFujiDeCupManager;

    address seller;
    address buyer;

    uint256 decupTCL;

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant FUJI_CHAIN_ID = 43113;

    uint256 public constant STARTING_BALANCE = 500 ether;

    //EncodeExtraArgs public encodeExtraArgs;

    function setUp() public {
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");

        helperConfigDeCup = new HelperConfigDeCup();
        helperConfigDeCupManager = new HelperConfigDeCupManager();

        string memory ETHEREUM_SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
        string memory AVALANCHE_FUJI_RPC_URL = vm.envString("AVALANCHE_FUJI_RPC_URL");

        ethSepoliaFork = vm.createSelectFork(ETHEREUM_SEPOLIA_RPC_URL);
        avlFujiFork = vm.createFork(AVALANCHE_FUJI_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        //1 Deploy DeCup.sol and DeCupManager.sol to Ethereum Sepolia
        assertEq(vm.activeFork(), ethSepoliaFork);

        vm.deal(seller, STARTING_BALANCE);
        vm.deal(buyer, STARTING_BALANCE);

        ethSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid); // we are currently on Ethereum Sepolia Fork
        assertEq(
            ethSepoliaNetworkDetails.chainSelector,
            16015286601757825753,
            "Sanity check: Ethereum Sepolia chain selector should be 16015286601757825753"
        );

        HelperConfigDeCup.NetworkConfig memory ethSepoliaConfigDeCup = helperConfigDeCup.getSepoliaEthConfig();
        HelperConfigDeCupManager.NetworkConfig memory ethSepoliaConfigDeCupManager =
            helperConfigDeCupManager.getSepoliaEthConfig();

        ethSepoliaDeCup = new DeCup(
            ethSepoliaConfigDeCup.imageURI,
            ethSepoliaConfigDeCup.tokenAddresses,
            ethSepoliaConfigDeCup.priceFeedAddresses,
            ethSepoliaConfigDeCup.defaultPriceFeed
        );

        ethSepoliaDeCupManager = new DeCupManager(
            address(ethSepoliaDeCup),
            ethSepoliaConfigDeCupManager.defaultPriceFeed,
            ethSepoliaConfigDeCupManager.destinationChainIds,
            ethSepoliaConfigDeCupManager.destinationChainSelectors,
            ethSepoliaConfigDeCupManager.linkTokens,
            ethSepoliaConfigDeCupManager.ccipRouters
        );

        //Transfer ownership of the DeCup NFT to the DeCupManager
        ethSepoliaDeCup.transferOwnership(address(ethSepoliaDeCupManager));

        //2 Deploy DeCup.sol and DeCupManager.sol to Avalanche Fuji
        vm.selectFork(avlFujiFork);
        assertEq(vm.activeFork(), avlFujiFork);

        vm.deal(seller, STARTING_BALANCE);
        vm.deal(buyer, STARTING_BALANCE);

        avlFujiNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid); // we are currently on Avalanche Fuji Fork
        assertEq(
            avlFujiNetworkDetails.chainSelector,
            14767482510784806043,
            "Sanity check: Avalanche Fuji chain selector should be 14767482510784806043"
        );

        HelperConfigDeCup.NetworkConfig memory avlFujiConfigDeCup = helperConfigDeCup.getFujiAvlConfig();
        HelperConfigDeCupManager.NetworkConfig memory avlFujiConfigDeCupManager =
            helperConfigDeCupManager.getFujiAvlConfig();

        avlFujiDeCup = new DeCup(
            avlFujiConfigDeCup.imageURI,
            avlFujiConfigDeCup.tokenAddresses,
            avlFujiConfigDeCup.priceFeedAddresses,
            avlFujiConfigDeCup.defaultPriceFeed
        );

        avlFujiDeCupManager = new DeCupManager(
            address(avlFujiDeCup),
            avlFujiConfigDeCupManager.defaultPriceFeed,
            avlFujiConfigDeCupManager.destinationChainIds,
            avlFujiConfigDeCupManager.destinationChainSelectors,
            avlFujiConfigDeCupManager.linkTokens,
            avlFujiConfigDeCupManager.ccipRouters
        );
        // Transfer ownership of the DeCup NFT to the DeCupManager
        avlFujiDeCup.transferOwnership(address(avlFujiDeCupManager));

        // 3. On Ethereum Sepolia, add the receiver address for Avalanche Fuji
        avlFujiDeCupManager.addChainReceiver(SEPOLIA_CHAIN_ID, address(ethSepoliaDeCupManager));

        // 4. On Ethereum Sepolia, add the receiver address for Avalanche Fuji
        vm.selectFork(ethSepoliaFork);
        assertEq(vm.activeFork(), ethSepoliaFork);
        ethSepoliaDeCupManager.addChainReceiver(FUJI_CHAIN_ID, address(avlFujiDeCupManager));
    }

    function testSetUp() public {
        // Fuji
        vm.selectFork(avlFujiFork);
        assertEq(vm.activeFork(), avlFujiFork);
        console.log("block.chainid", block.chainid);

        assertEq(avlFujiDeCupManager.getReceiverAddress(SEPOLIA_CHAIN_ID), address(ethSepoliaDeCupManager));
        assertEq(avlFujiDeCupManager.getChainSelector(SEPOLIA_CHAIN_ID), 16015286601757825753);
        assertEq(avlFujiDeCupManager.getChainSelector(FUJI_CHAIN_ID), 14767482510784806043);
        assertNotEq(avlFujiDeCupManager.getRouterAddress(SEPOLIA_CHAIN_ID), address(0));
        assertNotEq(avlFujiDeCupManager.getLinkAddress(SEPOLIA_CHAIN_ID), address(0));
        assertNotEq(avlFujiDeCupManager.getRouterAddress(FUJI_CHAIN_ID), address(0));
        assertNotEq(avlFujiDeCupManager.getLinkAddress(FUJI_CHAIN_ID), address(0));

        // Sepolia
        vm.selectFork(ethSepoliaFork);
        assertEq(vm.activeFork(), ethSepoliaFork);

        assertEq(ethSepoliaDeCupManager.getReceiverAddress(FUJI_CHAIN_ID), address(avlFujiDeCupManager));
        assertEq(ethSepoliaDeCupManager.getChainSelector(SEPOLIA_CHAIN_ID), 16015286601757825753);
        assertEq(ethSepoliaDeCupManager.getChainSelector(FUJI_CHAIN_ID), 14767482510784806043);
        assertNotEq(ethSepoliaDeCupManager.getRouterAddress(SEPOLIA_CHAIN_ID), address(0));
        assertNotEq(ethSepoliaDeCupManager.getLinkAddress(SEPOLIA_CHAIN_ID), address(0));
        assertNotEq(ethSepoliaDeCupManager.getRouterAddress(FUJI_CHAIN_ID), address(0));
        assertNotEq(ethSepoliaDeCupManager.getLinkAddress(FUJI_CHAIN_ID), address(0));
    }

    /*//////////////////////////////////////////////////////////////
                     MINT ON SEPOLIA & SALE ON FUJI
    //////////////////////////////////////////////////////////////*/

    function testMintDeCupOnSepoliaAndListForSaleOnFuji() public {
        //uint256 priceInUsd = 2000;
        // 1. On Ethereum Sepolia, mintin DeCup NFT
        vm.selectFork(ethSepoliaFork);
        assertEq(vm.activeFork(), ethSepoliaFork);

        // 1.1 Mint DeCup NFT
        vm.startPrank(seller);
        console.log("seller address on sepolia", address(seller));
        (bool success,) = address(ethSepoliaDeCup).call{value: 1 ether}("");
        assertTrue(success);

        decupTCL = ethSepoliaDeCup.getTokenPriceInUsd(0);
        uint256 minCollateral = ethSepoliaDeCupManager.getCcipCollateralInEth();
        console.log("minCollateral", minCollateral);
        uint256 ethPrice = ethSepoliaDeCupManager.getEthUsdPrice();
        console.log("ethPrice", ethPrice);
        console.log("decupTCL", decupTCL);

        // 1.2 List DeCup NFT for sale on Avalanche Fuji
        ethSepoliaDeCupManager.createCrossSale{value: minCollateral}(0, seller, FUJI_CHAIN_ID);
        uint256 sellerDeCupManagerBalanceAfterListing = ethSepoliaDeCupManager.balanceOf(seller);
        uint256 sellerBalanceAfterListing = address(seller).balance;
        console.log("sellerBalanceAfterListing", sellerBalanceAfterListing);
        console.log("sellerDeCupManagerBalanceAfterListing", sellerDeCupManagerBalanceAfterListing);
        vm.stopPrank();

        // 2. On Avalanche Fuji, verify the sale is created
        //vm.selectFork(avlFujiFork);
        //assertEq(vm.activeFork(), avlFujiFork);
        //assert(avlFujiDeCupManager.s_saleCounter() > 0);

        // 2.1 Verify the sale is created
        ccipLocalSimulatorFork.switchChainAndRouteMessage(avlFujiFork);
        assertEq(vm.activeFork(), avlFujiFork);

        //console.log("avlFujiDeCupManager addeess", address(avlFujiDeCupManager));
        //console.log(avlFujiDeCupManager.s_saleCounter());
        assert(avlFujiDeCupManager.getSaleCounter() > 0);

        assertEq(avlFujiDeCupManager.getSaleOwner(0, SEPOLIA_CHAIN_ID), seller);

        vm.deal(buyer, STARTING_BALANCE);
        vm.startPrank(buyer);
        //vm.prank(buyer);

        uint256 requiredAvax = avlFujiDeCupManager.getPriceInETHIncludingCollateral(decupTCL);
        uint256 avaxAmountInUsd = avlFujiDeCupManager.getPriceInUsd(requiredAvax);
        console.log("requiredAvax", requiredAvax); //134 574 033 608 575 828 539
        console.log("buyer balance", address(buyer).balance); //500 000 000 000 000 000 000
        console.log("price in usd", avaxAmountInUsd); //500 000 000 000 000 000 000

        assert(address(buyer).balance >= requiredAvax);
        assert(avaxAmountInUsd >= decupTCL);

        console.log("seller balance on fuji before buy", address(seller).balance);
        //2399 4000 0000
        //132 873 018 534 226 098 472
        avlFujiDeCupManager.buyCrossSale{value: requiredAvax}(0, buyer, SEPOLIA_CHAIN_ID, false);

        // uint256 priceInETH = ethSepoliaDeCupManager.getPriceInETHIncludingCollateral(priceInUsd);
        // vm.stopPrank();
        console.log("deCupManager", address(avlFujiDeCupManager).balance);
        console.log("seller's deCupManager balance on fuji after buy", avlFujiDeCupManager.balanceOf(seller));
        console.log("buyer address on fuji", address(buyer));
        console.log("seller address on fuji", address(seller));

        vm.stopPrank();
        // For some reason, the withdrawFunds causes a crash of foundry.
        // Units test is passing properly.
        vm.prank(seller);
        avlFujiDeCupManager.withdrawFunds();
        console.log("seller balance after withdraw", address(seller).balance);
        //assert(address(seller).balance >= STARTING_BALANCE + requiredAvax);

        // 634 697 226 984 197 802 378
        // 634 866 612 187 989 521 547

        // console.log("seller balance", address(seller).balance);
        //uint256 minCollateral = ethSepoliaDeCupManager.getCcipCollateralInEth();
        console.log("minCollateral", minCollateral);
        assertEq(address(buyer).balance, STARTING_BALANCE - requiredAvax);

        ccipLocalSimulatorFork.switchChainAndRouteMessage(ethSepoliaFork);
        assertEq(vm.activeFork(), ethSepoliaFork);

        console.log("decup owner of a token", ethSepoliaDeCup.ownerOf(0));
        //assertEq(address(seller).balance, STARTING_BALANCE + requiredAvax);
    }
}
