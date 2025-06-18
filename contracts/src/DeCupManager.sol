// Regester tokenId for sale based on token networkId
// Register salerAddress for resceiving payment

// Unregester tokenId from sale

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IDeCup} from "./interfaces/IDeCup.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title DeCupManager
 * @notice Manages the sale and purchase of DeCup NFTs with USD-denominated pricing
 * @dev This contract acts as a marketplace for DeCup NFTs, handling order creation, cancellation, and execution
 * @dev Uses a simple price feed mechanism and charges a manager fee in USD converted to ETH
 * @author DeCup Team
 */
contract DeCupManager is Ownable, ReentrancyGuard {
    // Errors
    error DeCupManager__TokenNotListedForSale();
    error DeCupManager__InsufficientETH();
    error DeCupManager__SaleNotFound();
    error DeCupManager__InsufficientFunds();

    // State variables
    IDeCup private s_nft;

    uint8 public s_managerFeeInUSD;
    uint256 public s_saleId;
    address public s_priceFeedAddress;

    mapping(address buyer => mapping(uint256 => uint256)) public s_buyerToSaleIdAmountPaied;
    mapping(uint256 saleId => address sellerAddress) public s_saleIdToSellerAddress;

    // Events
    event SaleCreated(uint256 indexed saleId, uint256 indexed tokenId, address indexed sellerAddress);

    /**
     * @notice Initializes the DeCupManager contract
     * @dev Sets up the NFT contract reference and price feed address
     * @param decupAddress The address of the DeCup NFT contract
     * @param priceFeedAddress The address of the price feed contract (currently unused)
     */
    constructor(address decupAddress, address priceFeedAddress) Ownable(msg.sender) {
        s_nft = IDeCup(decupAddress);
        s_priceFeedAddress = priceFeedAddress;
    }

    /**
     * @notice Transfers ownership of the DeCup NFT contract to a new owner
     * @dev Only callable by the current owner of this manager contract
     * @param newOwner The address of the new owner
     */
    function transferOwnershipOfDeCup(address newOwner) external onlyOwner {
        s_nft.transferOwnership(newOwner);
    }

    /**
     * @notice Set the manager fee in USD
     * @dev The fee is added to the token price when calculating the total cost in ETH
     * @param managerFeeInUSD The manager fee in USD (uint8 to limit maximum fee)
     */
    function setManagerFeeInUSD(uint8 managerFeeInUSD) public onlyOwner nonReentrant {
        s_managerFeeInUSD = managerFeeInUSD;
    }

    /**
     * @notice Creates a new sale order for a DeCup NFT
     * @dev The token must be listed for sale in the NFT contract before creating an order
     * @dev Increments the sale ID counter and emits a SaleCreated event
     * @param tokenId The ID of the token to be sold
     * @param beneficiaryAddress The address that will receive payment (defaults to token owner if zero address)
     */
    function createOrder(uint256 tokenId, address beneficiaryAddress) external nonReentrant {
        // Check if token is listed for sale
        if (!s_nft.getIsListedForSale(tokenId)) {
            revert DeCupManager__TokenNotListedForSale();
        }

        // Set seller address
        address sellerAddress = beneficiaryAddress == address(0) ? s_nft.ownerOf(tokenId) : beneficiaryAddress;
        s_saleIdToSellerAddress[s_saleId] = sellerAddress;
        emit SaleCreated(s_saleId, tokenId, sellerAddress);
        s_saleId++;
    }

    /**
     * @notice Cancels an existing sale order
     * @dev Removes the seller address mapping for the given sale ID
     * @dev Only the seller or contract owner can cancel orders (access control should be added)
     * @param saleId The ID of the sale to cancel
     */
    function cancelOrder(uint256 saleId) external nonReentrant {
        address sellerAddress = s_saleIdToSellerAddress[saleId];
        if (sellerAddress == address(0)) {
            revert DeCupManager__SaleNotFound();
        }
        s_saleIdToSellerAddress[saleId] = address(0);
    }

    /**
     * @notice Executes a buy order for a DeCup NFT
     * @dev Buyer must send sufficient ETH to cover the token price plus manager fee
     * @dev Records the payment amount but doesn't complete the transfer (additional logic needed)
     * @param saleId The ID of the sale to purchase
     */
    function buyOrder(uint256 saleId) external payable nonReentrant {
        uint256 priceInETH = getPriceInETH(saleId);
        if (msg.value < priceInETH) {
            revert DeCupManager__InsufficientETH();
        }
        s_buyerToSaleIdAmountPaied[msg.sender][saleId] = msg.value;
    }

    /**
     * @notice Returns the current USD to ETH conversion rate
     * @dev Currently hardcoded to 0.01 ETH per USD (should be replaced with actual price feed)
     * @return The ETH value equivalent to 1 USD
     */
    function getUSDETHValue() public view returns (uint256) {
        return 0.01 ether; // return ETH value of 1 USD
    }

    /**
     * @notice Calculates the total price in ETH for a token including manager fee
     * @dev Gets the token's TCL value in USD from the NFT contract and converts to ETH
     * @dev Adds the manager fee to the final price
     * @param tokenId The ID of the token to price
     * @return The total price in ETH (token price + manager fee)
     */
    function getPriceInETH(uint256 tokenId) public view returns (uint256) {
        uint256 priceInUSD = s_nft.getTokenIdTCL(tokenId);
        uint256 priceInETH = (priceInUSD * getUSDETHValue()) + (s_managerFeeInUSD * getUSDETHValue());
        return priceInETH;
    }
}

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// CEI:
// Check
// Effect
// Interaction
