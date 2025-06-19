// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {IDeCup} from "./interfaces/IDeCup.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title DeCupManager
 * @notice Manages the sale and purchase of DeCup NFTs with USD-denominated pricing
 * @dev This contract acts as a marketplace for DeCup NFTs, handling order creation, cancellation, and execution
 * @dev Uses a simple price feed mechanism and charges a manager fee in USD converted to ETH
 * @author DeCup Team
 */
contract DeCupManager is Ownable, ReentrancyGuard {
    // Interfaces
    IDeCup private s_nft;

    // Errors
    error DeCupManager__TokenNotListedForSale();
    error DeCupManager__TokenListedForSale();
    error DeCupManager__NotOwner();

    error DeCupManager__InsufficientETH();
    error DeCupManager__SaleNotFound();
    error DeCupManager__InsufficientFunds();
    error DeCupManager__TransferFailed();
    error DeCupManager__MoreThanZero();

    // Type declarations
    struct Order {
        uint256 tokenId;
        address sellerAddress;
        uint64 networkId;
    }

    // State variables
    uint256 public s_ccipCollateral; // collateral for interaction with CCIP, like ccipCollateral
    address public s_priceFeedAddress;
    uint256 public s_saleCounter;

    mapping(address user => uint256 collateral) public s_userToCollateral;
    mapping(uint256 saleId => address buyerAddress) public s_saleIdToBuyerAddress;
    mapping(address buyer => mapping(uint256 => uint256)) public s_buyerPaiedAmount;
    mapping(uint256 saleId => Order saleOrder) public s_saleIdToSaleOrder;
    mapping(uint64 chainId => uint64 chainSelector) public s_chainIdToChainSelector;
    mapping(uint64 chainId => address linkAddress) public s_chainIdToLinkAddress;
    mapping(uint64 chainId => address receiverAddress) public s_chainIdToReceiverAddress;
    mapping(uint64 chainId => address routerAddress) public s_chainIdToRouterAddress;

    // Events
    event Fund(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event CancelSale(uint256 indexed saleId);
    event CreateSale(uint256 indexed saleId, uint256 indexed tokenId, address indexed sellerAddress);
    event Buy(uint256 indexed saleId, address indexed buyerAddress, uint256 amountPaied);
    event FinalizeBuy(uint256 indexed saleId, address indexed buyerAddress, uint256 amountPaied);

    //Modifiers
    /**
     * @notice Modifier to check if the amount is greater than zero
     * @dev Reverts if the amount is zero
     */
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DeCupManager__MoreThanZero();
        }
        _;
    }

    /**
     * @notice Initializes the DeCupManager contract
     * @dev Sets up the NFT contract reference and price feed address
     * @param decupAddress The address of the DeCup NFT contract
     * @param priceFeedAddress The address of the price feed contract (currently unused)
     */
    constructor(address decupAddress, address priceFeedAddress) Ownable(msg.sender) {
        s_nft = IDeCup(decupAddress);
        s_priceFeedAddress = priceFeedAddress;
        s_ccipCollateral = 0.01 ether;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Receives ETH from the user
     * @dev Only callable if the amount is greater than zero
     * @dev The collateral is added to the contract and the user's balance is updated
     */
    receive() external payable moreThanZero(msg.value) nonReentrant {
        _addCollateral(msg.sender, msg.value);
    }

    /**
     * @notice Withdraws the collateral from the contract
     * @dev Only callable by the owner of the contract
     * @dev The collateral is removed from the contract and the user's balance is updated
     */
    function withdrawFunds() external nonReentrant {
        _removeCollateral(msg.sender);
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
     * @notice Creates a new cross-chain sale order for a locally minted DeCup NFT
     * @dev The token must NOT be listed for sale on the target chain before creating an order
     * @dev Creates a new sale order on target chain and stores it in the mapping saleId => saleOrder (tokenId, sellerAddress, buyerAddress, networkId)
     * @dev Increments the sale ID counter and emits a SaleCreated event (saleId, tokenId, sellerAddress)
     * @dev Lists the token for sale in the NFT contract after creating the order
     */
    function createCrossSale(uint256 tokenId, address beneficiaryAddress, uint64 networkId)
        external
        payable
        moreThanZero(msg.value)
        nonReentrant
    {
        // Checks
        if (msg.value < s_ccipCollateral) {
            revert DeCupManager__InsufficientETH();
        }

        if (s_nft.getIsListedForSale(tokenId)) {
            revert DeCupManager__TokenListedForSale();
        }
        if (s_nft.ownerOf(tokenId) != msg.sender) {
            revert DeCupManager__NotOwner();
        }

        // Effects
        _addCollateral(msg.sender, msg.value);

        // Interactions
        //Call ccip message to execute internalfunction _createSale on destination chain
        _createSale(tokenId, beneficiaryAddress, networkId);
    }

    /**
     * @notice Cancels a cross-chain sale order
     * @dev The collateral amount is required to cover CCIP fees for cross-chain token transfers
     * @dev Actual nft token is minted on the same chain as the manager contract I interact with!
     * @param saleId The ID of the sale to cancel
     */
    function cancelCrossSale(uint256 saleId, uint64 networkId, uint256 tokenId) external payable nonReentrant {
        if (msg.value < s_ccipCollateral) {
            revert DeCupManager__InsufficientETH();
        }

        if (!s_nft.getIsListedForSale(tokenId)) {
            revert DeCupManager__TokenNotListedForSale();
        }

        _addCollateral(msg.sender, msg.value);
        s_nft.removeFromSale(tokenId);
        // Call ccip message to execute internal function _cancelSale on destination chain
        _cancelSale(saleId);
    }

    /**
     * @notice Executes a buy order for a DeCup NFT
     * @dev Buyer must send sufficient ETH to cover the token price plus manager fee
     * @dev Records the payment amount but doesn't complete the transfer (additional logic needed)
     * @param saleId The ID of the sale to purchase
     */
    function buy(uint256 saleId, uint256 priceInUsd) external payable nonReentrant {
        uint256 priceInETH = getPriceInETH(priceInUsd);
        if (msg.value < priceInETH) {
            revert DeCupManager__InsufficientETH();
        }
        s_buyerPaiedAmount[msg.sender][saleId] = msg.value;
        s_saleIdToBuyerAddress[saleId] = msg.sender;
        emit Buy(saleId, msg.sender, priceInETH);
        // Interactions
        // Call internal ccip function to transfer token to buyer
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the CCIP collateral amount required for cross-chain transfers
     * @dev The collateral amount is required to cover CCIP fees for cross-chain token transfers
     * @dev This amount is stored in wei as a fixed ETH amount (default: 0.01 ether)
     * @param amount The collateral amount in wei
     */
    function setCcipCollateral(uint256 amount) public onlyOwner nonReentrant {
        s_ccipCollateral = amount;
    }

    /**
     * @notice Creates a new local sale order for a DeCup NFT
     * @param tokenId The ID of the token to be sold
     * @param beneficiaryAddress The address that will receive payment (defaults to token owner if zero address)
     * @dev The token must NOT be listed for sale in the NFT contract before creating an order
     * @dev Creates a new sale order and stores it in the mapping saleId => saleOrder (tokenId, sellerAddress, buyerAddress, networkId)
     * @dev Increments the sale ID counter and emits a SaleCreated event (saleId, tokenId, sellerAddress)
     * @dev Lists the token for sale in the NFT contract after creating the order
     */
    function createSale(uint256 tokenId, address beneficiaryAddress, uint64 networkId) public nonReentrant {
        // Check if token is listed for sale on target chain, before call creating an order
        if (s_nft.getIsListedForSale(tokenId)) {
            revert DeCupManager__TokenListedForSale();
        }

        if (s_nft.ownerOf(tokenId) != msg.sender) {
            revert DeCupManager__NotOwner();
        }
        // Effects
        address sellerAddress = beneficiaryAddress == address(0) ? s_nft.ownerOf(tokenId) : beneficiaryAddress;
        _createSale(tokenId, sellerAddress, networkId);
        // Interactions
        s_nft.listForSale(tokenId);
    }

    /**
     * @notice Cancels an existing sale order
     * @dev Removes the seller address mapping for the given sale ID
     * @dev Only the seller or contract owner can cancel orders (access control should be added)
     * @param saleId The ID of the sale to cancel
     */
    function cancelSale(uint256 saleId) public nonReentrant {
        // Checks
        Order memory saleOrder = s_saleIdToSaleOrder[saleId];
        if (saleOrder.sellerAddress == address(0)) {
            revert DeCupManager__SaleNotFound();
        }

        if (!s_nft.getIsListedForSale(saleOrder.tokenId)) {
            revert DeCupManager__TokenNotListedForSale();
        }

        // Effects
        _cancelSale(saleId);

        // Interactionss
        s_nft.removeFromSale(saleOrder.tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new sale order for a DeCup NFT
     * @dev Creates a new sale order and stores it in the mapping saleId => saleOrder (tokenId, sellerAddress, buyerAddress, networkId)
     * @dev Increments the sale ID counter and emits a SaleCreated event (saleId, tokenId, sellerAddress)
     */
    function _createSale(uint256 tokenId, address sellerAddress, uint64 networkId) internal {
        uint256 saleId = s_saleCounter;
        Order memory saleOrder = Order({tokenId: tokenId, sellerAddress: sellerAddress, networkId: networkId});
        s_saleIdToSaleOrder[saleId] = saleOrder;
        s_saleCounter++;
        emit CreateSale(saleId, tokenId, sellerAddress);
    }

    /**
     * @notice Cancels a sale order
     * @dev Deletes the sale order from the mapping saleId => saleOrder
     * @dev Emits a SaleCanceled event (saleId)
     */
    function _cancelSale(uint256 saleId) internal {
        delete s_saleIdToSaleOrder[saleId];
        emit CancelSale(saleId);
    }

    /**
     * @notice Finalizes a buy order for a DeCup NFT
     * @dev Transfers the token to the buyer and releases the funds to the seller
     * @dev This function supposed to be called by ccip in responce to the ccip message call
     * @param saleId The ID of the sale to finalize
     */
    function _finalizeBuy(uint256 saleId) internal {
        Order memory saleOrder = s_saleIdToSaleOrder[saleId];
        address buyerAddress = s_saleIdToBuyerAddress[saleId];
        uint256 amountPaied = s_buyerPaiedAmount[buyerAddress][saleId];
        s_buyerPaiedAmount[buyerAddress][saleId] = 0;
        s_saleIdToBuyerAddress[saleId] = address(0);
        _addCollateral(saleOrder.sellerAddress, amountPaied);
        emit FinalizeBuy(saleId, buyerAddress, amountPaied);
    }

    /**
     * @notice Adds collateral to the contract
     * @dev Adds collateral to the contract and emits a Fund event (user, amount)
     */
    function _addCollateral(address user, uint256 amount) internal {
        s_userToCollateral[user] += amount;
        emit Fund(user, amount);
    }

    /**
     * @notice Removes collateral from the contract
     * @dev Removes collateral from the contract and emits a Withdraw event (user, amount)
     */
    function _removeCollateral(address user) internal {
        uint256 amount = s_userToCollateral[user];
        if (amount == 0) {
            revert DeCupManager__InsufficientFunds();
        }
        s_userToCollateral[user] -= amount;
        emit Withdraw(user, amount);
    }

    /*//////////////////////////////////////////////////////////////
                EXTERNAL / PUBLIC VIEW / PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current USD to ETH conversion rate
     * @dev Currently hardcoded to 0.01 ETH per USD (should be replaced with actual price feed)
     * @return The ETH value equivalent to 1 USD
     */
    function getEthUsdPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeedAddress);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price); // return ETH value of 1 USD
    }

    /**
     * @notice Calculates the total price in ETH for a given USD amount including CCIP collateral
     * @dev Converts USD price to ETH using price feed and adds CCIP collateral fee
     * @param priceInUSD The USD price to convert to ETH (with ß8 decimals)
     * @return The total price in ETH (wei units)
     */
    function getPriceInETH(uint256 priceInUSD) public view returns (uint256) {
        // Convert NFT price from USD to ETH
        // priceInUSD has 8 decimals, getEthUsdPrice() has 8 decimals
        // Division cancels out decimals, so multiply by 1e18 to get wei
        uint256 nftPriceInETH = (priceInUSD * 1e18) / getEthUsdPrice();

        // Add fixed collateral amount (0.01 ether)
        return nftPriceInETH + s_ccipCollateral;
    }

    /**
     * @notice Returns the address of the DeCup NFT contract
     * @dev Returns the address of the DeCup NFT contract
     */
    function getDeCupAddress() public view returns (address) {
        return address(s_nft);
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
