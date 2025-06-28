// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

interface IDeCupManager {
    // Enums
    enum PayFeesIn {
        Native,
        LINK
    }

    enum CrossChainAction {
        CreateSale,
        CancelSale,
        Buy
    }

    // Structs
    struct Order {
        uint256 tokenId;
        address sellerAddress;
        address beneficiaryAddress;
        uint256 chainId;
    }

    struct CrossChainMessage {
        CrossChainAction action;
        uint256 saleId;
        address buyerAddress;
        bool isBurn;
        Order order;
        uint256 priceInUsd;
    }

    // Custom Errors
    error DeCupManager__TokenNotListedForSale();
    error DeCupManager__TokenListedForSale();
    error DeCupManager__NotOwner();
    error DeCupManager__InsufficientETH();
    error DeCupManager__SaleNotFound();
    error DeCupManager__InsufficientFunds();
    error DeCupManager__TransferFailed();
    error DeCupManager__MoreThanZero();
    error DeCupManager__NotTokenOwner();
    error DeCupManager__NotRouter();
    error DeCupManager__InvalidAction();
    error DeCupManager__InvalidRouter(address, uint256);

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event CancelSale(uint256 indexed saleId);
    event CreateSale(
        uint256 indexed saleId,
        uint256 indexed tokenId,
        address indexed sellerAddress,
        uint256 sourceChainId,
        uint256 destinationChainId
    );
    event Buy(uint256 indexed saleId, address indexed buyerAddress, uint256 amountPaied);
    event BuyCrossSale(
        uint256 indexed saleId, address indexed buyerAddress, uint256 amountPaied, address indexed sellerAddress
    );
    event CrossChainReceived(bytes32 messageId, uint64 sourceChainSelector, uint64 destinationChainSelector);
    event CrossChainDataReceived(
        CrossChainAction action,
        uint256 saleId,
        uint256 tokenId,
        address sellerAddress,
        address beneficiaryAddress,
        uint256 chainId,
        address buyerAddress,
        bool isBurn,
        uint256 priceInUsd
    );
    event CrossChainSent(bytes32 messageId, uint64 sourceChainSelector, uint64 destinationChainSelector);
    event CrossChainDataSent(
        CrossChainAction action,
        uint256 saleId,
        uint256 tokenId,
        address sellerAddress,
        address beneficiaryAddress,
        uint256 chainId,
        address buyerAddress,
        bool isBurn,
        uint256 priceInUsd
    );

    // State variables getters
    function s_ccipCollateralInUsd() external view returns (uint256);
    function s_priceFeedAddress() external view returns (address);
    function s_saleCounter() external view returns (uint256);
    function s_payFeesIn() external view returns (PayFeesIn);
    function s_chainIdToSaleIdToSaleOrder(uint256 chainId, uint256 saleId) external view returns (Order memory);
    function s_chainIdToChainSelector(uint256 chainId) external view returns (uint64);
    function s_chainIdToLinkAddress(uint256 chainId) external view returns (address);
    function s_chainIdToReceiverAddress(uint256 chainId) external view returns (address);
    function s_chainIdToRouterAddress(uint256 chainId) external view returns (address);

    // External Functions
    receive() external payable;
    function withdrawFunds() external;
    function transferOwnershipOfDeCup(address newOwner) external;
    function createCrossSale(uint256 tokenId, address beneficiaryAddress, uint256 destinationChainId)
        external
        payable;
    function cancelCrossSale(uint256 saleId, uint256 destinationChainId, uint256 tokenId) external payable;
    function buyCrossSale(uint256 saleId, address buyerBeneficiaryAddress, uint256 destinationChainId, bool isBurn)
        external
        payable;
    function ccipReceive(Client.Any2EVMMessage memory message) external;
    function getSaleOwner(uint256 saleId, uint256 chainId) external view returns (address);
    function enableChain(
        uint256 chainId,
        uint64 chainSelector,
        address linkAddress,
        address receiverAddress,
        address routerAddress
    ) external;
    function addChainReceiver(uint256 chainId, address receiverAddress) external;
    function disableChain(uint256 chainId) external;
    function deleteChainReceiver(uint256 chainId) external;
    function buy(uint256 saleId, address buyerBeneficiaryAddress, bool isBurn) external payable;
    function setCcipCollateral(uint256 amount) external;
    function createSale(uint256 tokenId, address beneficiaryAddress) external;
    function cancelSale(uint256 saleId) external;

    // View Functions
    function getEthUsdPrice() external view returns (uint256);
    function getPriceInETH(uint256 priceInUSD) external view returns (uint256);
    function getPriceInUsd(uint256 priceInETH) external view returns (uint256);
    function getPriceInETHIncludingCollateral(uint256 priceInUSD) external view returns (uint256);
    function getDeCupAddress() external view returns (address);
    function balanceOf(address user) external view returns (uint256);
    function getCCIPRouter() external view returns (address);
    function getCcipCollateralInEth() external view returns (uint256);
}
