// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {MockToken} from "test/mocks/MockToken.sol";

contract HelperConfigDeCupManager is Script {
    struct NetworkConfig {
        address pricePriceFeed;
        address ccipRouter;
        address linkToken;
        uint64[] destinationChainIds;
        uint64[] destinationChainSelectors;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        uint64[] memory destinationChainIds = new uint64[](3);
        destinationChainIds[0] = 11155111; // Sepolia
        destinationChainIds[1] = 43114; // Avalanche Fuji
        destinationChainIds[2] = 84532; // Base Sepolia

        uint64[] memory destinationChainSelectors = new uint64[](3);
        destinationChainSelectors[0] = 16015286601757825753; // Ethereum Sepolia
        destinationChainSelectors[1] = 14767482510784806043; // Avalanche Fuji
        destinationChainSelectors[2] = 10344971235874465080; // Base Sepolia

        return NetworkConfig({
            ccipRouter: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59, // CCIP Router Sepolia
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // Link Token Sepolia
            destinationChainSelectors: destinationChainSelectors,
            destinationChainIds: destinationChainIds,
            pricePriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306 // ETH / USD Sepolia
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.destinationChainIds.length > 0) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        // MockToken wethMock = new MockToken("WETH", "WETH", msg.sender, 1000e18, 18);

        // MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        // MockToken wbtcMock = new MockToken("WBTC", "WBTC", msg.sender, 1000e8, 8);

        // MockV3Aggregator usdcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        // MockToken usdcMock = new MockToken("USDC", "USDC", msg.sender, 1000e6, 6);
        vm.stopBroadcast();

        // address[] memory priceFeedAddresses = new address[](3);
        // priceFeedAddresses[0] = address(ethUsdPriceFeed);
        // priceFeedAddresses[1] = address(btcUsdPriceFeed);
        // priceFeedAddresses[2] = address(usdcUsdPriceFeed);

        // address[] memory tokenAddresses = new address[](3);
        // tokenAddresses[0] = address(wethMock);
        // tokenAddresses[1] = address(wbtcMock);
        // tokenAddresses[2] = address(usdcMock);

        return NetworkConfig({
            ccipRouter: 0x6F40d92D6DC45a11D5f978752E9AA9E608B987F4, // CCIP Router
            linkToken: 0x0B98057ea310f4D31F2A4C08058175751A9B25DC, // Link Token
            destinationChainSelectors: new uint64[](0),
            destinationChainIds: new uint64[](0),
            pricePriceFeed: address(ethUsdPriceFeed)
        });
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
