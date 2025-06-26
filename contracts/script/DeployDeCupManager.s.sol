// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Script} from "forge-std/Script.sol";
import {DeCup} from "src/DeCup.sol";
import {DeCupManager} from "src/DeCupManager.sol";
import {HelperConfigDeCup} from "./HelperConfigDeCup.s.sol";
import {HelperConfigDeCupManager} from "./HelperConfigDeCupManager.s.sol";
import {DeployDeCup} from "./DeployDeCup.s.sol";

contract DeployDeCupManager is Script {
    DeCupManager decupManager;
    DeCup deCup;
    HelperConfigDeCup s_configDeCup;
    HelperConfigDeCupManager s_configDeCupManager;

    function run() external returns (DeCupManager, DeCup, HelperConfigDeCup, HelperConfigDeCupManager) {
        // Deploy DeCup
        DeployDeCup deployer = new DeployDeCup();
        (deCup, s_configDeCup) = deployer.run();

        s_configDeCupManager = new HelperConfigDeCupManager();
        HelperConfigDeCupManager.NetworkConfig memory networkConfigDCM = s_configDeCupManager.getConfig();

        decupManager = deployDeCupManager(
            address(deCup),
            networkConfigDCM.defaultPriceFeed,
            networkConfigDCM.destinationChainIds,
            networkConfigDCM.destinationChainSelectors,
            networkConfigDCM.linkTokens,
            networkConfigDCM.ccipRouters
        );

        return (decupManager, deCup, s_configDeCup, s_configDeCupManager);
    }

    function deployDeCupManager(
        address deCupAddress,
        address defaultPriceFeed,
        uint64[] memory destinationChainIds,
        uint64[] memory destinationChainSelectors,
        address[] memory linkTokens,
        address[] memory ccipRouters
    ) public returns (DeCupManager) {
        vm.startBroadcast();
        // Deploy DeCupManager
        DeCupManager deploy = new DeCupManager(
            deCupAddress, defaultPriceFeed, destinationChainIds, destinationChainSelectors, linkTokens, ccipRouters
        );
        // Transfer ownership of the DeCup NFT to the DeCupManager
        DeCup(payable(deCupAddress)).transferOwnership(address(deploy));
        vm.stopBroadcast();
        return deploy;
    }
}
