// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {DeCup} from "src/DeCup.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployDeCup is Script {
    function run() public {
        string memory svgDeCup = vm.readFile("./img/decup.svg");
        deployDeCup(svgToImageURI(svgDeCup));
    }

    function svgToImageURI(string memory _svg) public pure returns (string memory) {
        string memory baseURI = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(_svg))));
        return string.concat(baseURI, svgBase64Encoded);
    }

    function deployDeCup(string memory _svgDeCup) public returns (DeCup) {
        vm.startBroadcast();
        // Deploy with empty arrays for tokens and price feeds - can be configured later
        address[] memory tokenAddresses = new address[](0);
        address[] memory priceFeedAddresses = new address[](0);
        DeCup deploy = new DeCup(_svgDeCup, tokenAddresses, priceFeedAddresses);
        vm.stopBroadcast();
        return deploy;
    }
}
