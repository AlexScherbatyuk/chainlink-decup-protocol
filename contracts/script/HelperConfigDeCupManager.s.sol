// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {MockToken} from "test/mocks/MockToken.sol";

contract HelperConfigDeCupManager is Script {
    struct NetworkConfig {
        address defaultPriceFeed;
        address[] ccipRouters;
        address[] linkTokens;
        uint64[] destinationChainIds;
        uint64[] destinationChainSelectors;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8; //2406 6593 0000

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 43113) {
            activeNetworkConfig = getFujiAvlConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        uint64[] memory destinationChainIds = new uint64[](2);
        destinationChainIds[0] = 11155111; // Sepolia
        destinationChainIds[1] = 43113; // Avalanche Fuji

        uint64[] memory destinationChainSelectors = new uint64[](2);
        destinationChainSelectors[0] = 16015286601757825753; // Ethereum Sepolia
        destinationChainSelectors[1] = 14767482510784806043; // Avalanche Fuji

        address[] memory ccipRouters = new address[](2);
        ccipRouters[0] = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59; // CCIP Router Sepolia
        ccipRouters[1] = 0xF694E193200268f9a4868e4Aa017A0118C9a8177; // CCIP Router Fuji

        address[] memory linkTokens = new address[](2);
        linkTokens[0] = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Link Token Sepolia
        linkTokens[1] = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846; // Link Token Fuji

        return NetworkConfig({
            ccipRouters: ccipRouters, // CCIP Router Sepolia
            linkTokens: linkTokens, // Link Token Sepolia
            destinationChainSelectors: destinationChainSelectors,
            destinationChainIds: destinationChainIds,
            defaultPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306 // ETH / USD Sepolia
        });
    }

    function getFujiAvlConfig() public pure returns (NetworkConfig memory) {
        uint64[] memory destinationChainIds = new uint64[](2);
        destinationChainIds[0] = 11155111; // Sepolia
        destinationChainIds[1] = 43113; // Avalanche Fuji

        uint64[] memory destinationChainSelectors = new uint64[](2);
        destinationChainSelectors[0] = 16015286601757825753; // Ethereum Sepolia
        destinationChainSelectors[1] = 14767482510784806043; // Avalanche Fuji

        address[] memory ccipRouters = new address[](2);
        ccipRouters[0] = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59; // CCIP Router Sepolia
        ccipRouters[1] = 0xF694E193200268f9a4868e4Aa017A0118C9a8177; // CCIP Router Fuji

        address[] memory linkTokens = new address[](2);
        linkTokens[0] = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Link Token Sepolia
        linkTokens[1] = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846; // Link Token Fuji

        return NetworkConfig({
            ccipRouters: ccipRouters, // CCIP Router Sepolia
            linkTokens: linkTokens, // Link Token Sepolia
            destinationChainSelectors: destinationChainSelectors,
            destinationChainIds: destinationChainIds,
            defaultPriceFeed: 0x5498BB86BC934c8D34FDA08E81D444153d0D06aD // AVAX / USD Fuji
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

        uint64[] memory destinationChainIds = new uint64[](2);
        destinationChainIds[0] = 11155111; // Sepolia
        destinationChainIds[1] = 43114; // Avalanche Fuji

        uint64[] memory destinationChainSelectors = new uint64[](2);
        destinationChainSelectors[0] = 16015286601757825753; // Ethereum Sepolia
        destinationChainSelectors[1] = 14767482510784806043; // Avalanche Fuji

        address[] memory ccipRouters = new address[](2);
        ccipRouters[0] = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59; // CCIP Router Sepolia
        ccipRouters[1] = 0xF694E193200268f9a4868e4Aa017A0118C9a8177; // CCIP Router Fuji

        address[] memory linkTokens = new address[](2);
        linkTokens[0] = 0x779877A7B0D9E8603169DdbD7836e478b4624789; // Link Token Sepolia
        linkTokens[1] = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846; // Link Token Fuji

        return NetworkConfig({
            ccipRouters: ccipRouters, // CCIP Router Sepolia
            linkTokens: linkTokens, // Link Token Sepolia
            destinationChainSelectors: destinationChainSelectors,
            destinationChainIds: destinationChainIds,
            defaultPriceFeed: address(ethUsdPriceFeed)
        });
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
