// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {MockToken} from "test/mocks/MockToken.sol";

contract HelperConfigDeCup is Script {
    struct NetworkConfig {
        string imageURI;
        address[] tokenAddresses;
        address[] priceFeedAddresses;
        address defaultPriceFeed;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function svgToImageURI(string memory _svg) public pure returns (string memory) {
        string memory baseURI = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(_svg))));
        return string.concat(baseURI, svgBase64Encoded);
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        string memory imageURI = svgToImageURI(vm.readFile("./img/ethereum-mug.svg"));

        address[] memory priceFeedAddresses = new address[](3);
        priceFeedAddresses[0] = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // ETH / USD
        priceFeedAddresses[1] = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43; // BTC / USD
        priceFeedAddresses[2] = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E; // USDC / USD

        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81; // WETH
        tokenAddresses[1] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063; // WBTC
        tokenAddresses[2] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC

        return NetworkConfig({
            imageURI: imageURI,
            priceFeedAddresses: priceFeedAddresses,
            tokenAddresses: tokenAddresses,
            defaultPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
    }

    function getFujiAvlConfig() public view returns (NetworkConfig memory) {
        string memory imageURI = svgToImageURI(vm.readFile("./img/avalanche-mug.svg"));

        address[] memory priceFeedAddresses = new address[](3);
        priceFeedAddresses[0] = 0x5498BB86BC934c8D34FDA08E81D444153d0D06aD; // AVAX / USD
        priceFeedAddresses[1] = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43; // BTC / USD
        priceFeedAddresses[2] = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E; // USDC / USD

        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c; // WAVAX
        tokenAddresses[1] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063; // WBTC
        tokenAddresses[2] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC

        return NetworkConfig({
            imageURI: imageURI,
            priceFeedAddresses: priceFeedAddresses,
            tokenAddresses: tokenAddresses,
            defaultPriceFeed: 0x5498BB86BC934c8D34FDA08E81D444153d0D06aD
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        string memory imageURI = svgToImageURI(vm.readFile("./img/decup.svg"));
        if (activeNetworkConfig.priceFeedAddresses.length > 0) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        MockToken wethMock = new MockToken("WETH", "WETH", msg.sender, 1000e18, 18);

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        MockToken wbtcMock = new MockToken("WBTC", "WBTC", msg.sender, 1000e8, 8);

        MockV3Aggregator usdcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        MockToken usdcMock = new MockToken("USDC", "USDC", msg.sender, 1000e6, 6);
        vm.stopBroadcast();

        address[] memory priceFeedAddresses = new address[](3);
        priceFeedAddresses[0] = address(ethUsdPriceFeed);
        priceFeedAddresses[1] = address(btcUsdPriceFeed);
        priceFeedAddresses[2] = address(usdcUsdPriceFeed);

        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = address(wethMock);
        tokenAddresses[1] = address(wbtcMock);
        tokenAddresses[2] = address(usdcMock);

        return NetworkConfig({
            imageURI: imageURI,
            priceFeedAddresses: priceFeedAddresses,
            tokenAddresses: tokenAddresses,
            defaultPriceFeed: address(ethUsdPriceFeed)
        });
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }
}
