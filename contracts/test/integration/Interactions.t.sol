// SPDX-License-Identifier: MIT

pragma solidity 0.8.29;

import {Test, console} from "forge-std/Test.sol";
import {DeCup} from "src/DeCup.sol";
import {DeployDeCup} from "script/DeployDeCup.s.sol";
import {
    DepositMultipleAssetsAndMintNft,
    DepositNativeCurrencyAndMintNft,
    DepositSingleAssetAndMintNft,
    AddNativeCollateralToExistingCup,
    AddSingleAssetCollateralToExistingCup,
    BurnDeCupNft,
    GetNftMetadata,
    GetNftCollateral,
    GetNftTCLOfToken,
    ListForSale,
    RemoveFromSale
} from "script/Interactions.s.sol";

contract InteractionsTest is Test {
    function setUp() public {}

    function testDepositNativeCurrencyAndMintNft() public {
        DepositNativeCurrencyAndMintNft deploy = new DepositNativeCurrencyAndMintNft();
        address deCupAddress = deploy.run();
        assert(deCupAddress.balance > 0);
    }
}
