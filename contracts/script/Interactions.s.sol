// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {DeCup} from "src/DeCup.sol";
import {HelperConfigDeCup} from "./HelperConfigDeCup.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract DepositMultipleAssetsAndMintNft is Script {
    function run() external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        depositMultipleAssetsAndMintNft(mostRecentlDeployed);

        return mostRecentlDeployed;
    }

    function depositMultipleAssetsAndMintNft(address deCupAddress) public {
        HelperConfigDeCup config = new HelperConfigDeCup();
        HelperConfigDeCup.NetworkConfig memory networkConfig = config.getConfig();

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 5e17;
        amounts[1] = 1e8;
        amounts[2] = 5e6;
        vm.startBroadcast();
        DeCup(payable(deCupAddress)).depositMultipleAssetsAndMint(networkConfig.tokenAddresses, amounts);
        vm.stopBroadcast();
    }
}

contract DepositNativeCurrencyAndMintNft is Script {
    function run() external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        depositNativeCurrencyAndMintNft(mostRecentlDeployed);

        return mostRecentlDeployed;
    }

    function depositNativeCurrencyAndMintNft(address deCupAddress) public returns (DeCup) {
        vm.startBroadcast();
        (bool success,) = deCupAddress.call{value: 1 ether}("");
        if (!success) {
            revert DeCup.DeCup__TransferFailed();
        }
        vm.stopBroadcast();
        return DeCup(payable(deCupAddress));
    }
}

contract DepositSingleAssetAndMintNft is Script {
    function run() external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        depositSingleAssetAndMintNft(mostRecentlDeployed);

        return mostRecentlDeployed;
    }

    function depositSingleAssetAndMintNft(address deCupAddress) public {
        HelperConfigDeCup config = new HelperConfigDeCup();
        HelperConfigDeCup.NetworkConfig memory networkConfig = config.getConfig();

        vm.startBroadcast();
        DeCup(payable(deCupAddress)).depositSingleAssetAndMint(networkConfig.tokenAddresses[3], 5e6);
        vm.stopBroadcast();
    }
}

contract AddNativeCollateralToExistingCup is Script {
    function run(uint256 tokenId) external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        addNativeCollateralToExistingCup(mostRecentlDeployed, tokenId);

        return mostRecentlDeployed;
    }

    function addNativeCollateralToExistingCup(address deCupAddress, uint256 tokenId) public {
        vm.startBroadcast();
        DeCup(payable(deCupAddress)).addNativeCollateralToExistingCup{value: 1 ether}(tokenId);
        vm.stopBroadcast();
    }
}

contract AddSingleAssetCollateralToExistingCup is Script {
    function run(uint256 tokenId) external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        addSingleAssetCollateralToExistingCup(mostRecentlDeployed, tokenId);

        return mostRecentlDeployed;
    }

    function addSingleAssetCollateralToExistingCup(address deCupAddress, uint256 tokenId) public {
        HelperConfigDeCup config = new HelperConfigDeCup();
        HelperConfigDeCup.NetworkConfig memory networkConfig = config.getConfig();
        vm.startBroadcast();
        DeCup(payable(deCupAddress)).addTokenCollateralToExistingCup(networkConfig.tokenAddresses[2], 5e6, tokenId);
        vm.stopBroadcast();
    }
}

contract BurnDeCupNft is Script {
    function run(uint256 tokenId) external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        burnDeCupNft(mostRecentlDeployed, tokenId);

        return mostRecentlDeployed;
    }

    function burnDeCupNft(address deCupAddress, uint256 tokenId) public {
        vm.startBroadcast();
        DeCup(payable(deCupAddress)).burn(tokenId);
        vm.stopBroadcast();
    }
}

contract GetNftMetadata is Script {
    function run(uint256 tokenId) external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        getNftMetadata(mostRecentlDeployed, tokenId);

        return mostRecentlDeployed;
    }

    function getNftMetadata(address deCupAddress, uint256 tokenId) public {
        vm.startBroadcast();
        DeCup(payable(deCupAddress)).tokenURI(tokenId);
        vm.stopBroadcast();
    }
}

contract GetNftCollateral is Script {
    function run(uint256 tokenId, address tokenAddress) external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        getNftCollateral(mostRecentlDeployed, tokenId, tokenAddress);

        return mostRecentlDeployed;
    }

    function getNftCollateral(address deCupAddress, uint256 tokenId, address tokenAddress) public {
        vm.startBroadcast();
        DeCup(payable(deCupAddress)).getCollateralBalance(tokenId, tokenAddress); //getTokenPriceInUsd(tokenId);
        vm.stopBroadcast();
    }
}

contract GetNftTCLOfToken is Script {
    function run(uint256 tokenId) external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        getNftTCLOfToken(mostRecentlDeployed, tokenId);

        return mostRecentlDeployed;
    }

    function getNftTCLOfToken(address deCupAddress, uint256 tokenId) public {
        vm.startBroadcast();
        DeCup(payable(deCupAddress)).getTokenPriceInUsd(tokenId);
        vm.stopBroadcast();
    }
}

contract ListForSale is Script {
    function run(uint256 tokenId) external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        listForSale(mostRecentlDeployed, tokenId);

        return mostRecentlDeployed;
    }

    function listForSale(address deCupAddress, uint256 tokenId) public {
        vm.startBroadcast();
        DeCup(payable(deCupAddress)).listForSale(tokenId);
        vm.stopBroadcast();
    }
}

contract RemoveFromSale is Script {
    function run(uint256 tokenId) external returns (address) {
        address mostRecentlDeployed = DevOpsTools.get_most_recent_deployment("DeCup", block.chainid);

        removeFromSale(mostRecentlDeployed, tokenId);

        return mostRecentlDeployed;
    }

    function removeFromSale(address deCupAddress, uint256 tokenId) public {
        vm.startBroadcast();
        DeCup(payable(deCupAddress)).removeFromSale(tokenId);
        vm.stopBroadcast();
    }
}
