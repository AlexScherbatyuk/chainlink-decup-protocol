// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {DeCupNft} from "src/DeCupNft.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployDeCupNft is Script {

    function run() public {
        string memory svgDeCup = vm.readFile("./img/decup.svg");
        deployDeCupNft(svgDeCup);
    }

    function svgToImageURI(string memory _svg) public pure returns (string memory) {
        string memory baseURI = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(_svg))));
        return string.concat(baseURI, svgBase64Encoded);
    }

    function deployDeCupNft(string memory _svgDeCup) public returns(DeCupNft){
        DeCupNft deploy = new DeCupNft(_svgDeCup);
        return deploy;
    }
}