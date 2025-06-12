// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {DeCup} from "src/DeCup.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDeCup is Script {
    //  HelperConfig helperConfig;

    function run() external returns (DeCup, HelperConfig) {
        HelperConfig config = new HelperConfig();
        // (string memory imageURI, address[] memory tokenAddresses, address[] memory priceFeedAddresses) =
        //     config.activeNetworkConfig();

        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();

        DeCup decup = deployDeCup(
            networkConfig.imageURI,
            networkConfig.tokenAddresses,
            networkConfig.priceFeedAddresses,
            networkConfig.defaultPriceFeed
        );
        return (decup, config);
    }

    // function svgToImageURI(string memory _svg) public view returns (string memory) {
    //     return helperConfig.svgToImageURI(_svg);
    // }

    function deployDeCup(
        string memory imageURI,
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address defaultPriceFeed
    ) public returns (DeCup) {
        vm.startBroadcast();
        // Deploy with empty arrays for tokens and price feeds - can be configured later
        // address[] memory tokenAddresses = new address[](0);
        // address[] memory priceFeedAddresses = new address[](0);
        DeCup deploy = new DeCup(imageURI, tokenAddresses, priceFeedAddresses, defaultPriceFeed);
        vm.stopBroadcast();
        return deploy;
    }
}
