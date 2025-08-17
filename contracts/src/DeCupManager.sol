// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {IDeCup} from "./interfaces/IDeCup.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {CCIPReceiver} from "@chainlink/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol";

/**
 * @title Decentralized Cup Manager (DeCupManager)
 * @author Alexander Scherbatyuk
 * @notice Manages the sale and purchase of DeCup NFTs with USD-denominated pricing
 * @dev This contract acts as a marketplace for DeCup NFTs, handling order creation, cancellation, and execution
 * @dev Uses a simple price feed mechanism and charges a manager fee in USD converted to ETH
 */
contract DeCupManager is Ownable, CCIPReceiver, ReentrancyGuard {
    // Interfaces
    IDeCup private s_nft;
    LinkTokenInterface internal immutable i_linkToken;

    // Errors
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

    /**
     * @notice Enum to specify the payment method for CCIP fees
     * @dev Native: Pay fees in native token (ETH)
     * @dev LINK: Pay fees in LINK token
     */
    enum PayFeesIn {
        Native,
        LINK
    }

    /**
     * @notice Enum to specify the type of cross-chain action
     * @dev CreateSale: Create a new sale order
     * @dev CancelSale: Cancel an existing sale order
     * @dev Buy: Execute a buy order
     */
    enum CrossChainAction {
        CreateSale,
        CancelSale,
        Buy
    }

    /**
     * @notice Structure representing a sale order
     * @param tokenId The ID of the NFT being sold
     * @param sellerAddress The address of the seller
     * @param beneficiaryAddress The address that will receive the payment
     * @param chainId The chain ID where the sale is active
     * @param priceInUsd The price of the NFT in USD (with 8 decimals)
     */
    struct Order {
        uint256 tokenId;
        address sellerAddress;
        address beneficiaryAddress;
        uint256 chainId;
        uint256 priceInUsd;
        string[] assetsInfo;
    }

    /**
     * @notice Structure representing a cross-chain message
     * @param action The type of action to perform
     * @param saleId The ID of the sale
     * @param buyerAddress The address of the buyer
     * @param isBurn Whether to burn the token after transfer
     * @param order The order details
     * @param priceInUsd The price paid in USD (with 8 decimals)
     */
    struct CrossChainMessage {
        CrossChainAction action;
        uint256 saleId;
        address buyerAddress;
        bool isBurn;
        Order order;
        uint256 priceInUsd;
    }

    // State variables
    uint256 private s_ccipCollateralInUsd;
    address private s_priceFeedAddress;
    uint256 private s_saleCounter;
    PayFeesIn private s_payFeesIn = PayFeesIn.Native;
    uint64 private immutable i_currentChainSelector;

    mapping(address user => uint256 collateral) private s_userToCollateral;
    mapping(uint256 chainId => mapping(uint256 saleId => Order saleOrder)) private s_chainIdToSaleIdToSaleOrder;
    mapping(uint256 chainId => uint64 chainSelector) private s_chainIdToChainSelector;
    mapping(uint256 chainId => address linkAddress) private s_chainIdToLinkAddress;
    mapping(uint256 chainId => address receiverAddress) private s_chainIdToReceiverAddress;
    mapping(uint256 chainId => address routerAddress) private s_chainIdToRouterAddress;
    mapping(uint256 chainId => mapping(uint256 tokenId => uint256 saleId)) private s_chainIdToTokenIdToSaleId;

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event CancelSale(uint256 indexed saleId);
    event CancelCrossSale(uint256 indexed tokenId);
    event CreateSale(uint256 indexed saleId, uint256 indexed tokenId, address indexed sellerAddress, uint256 sourceChainId, uint256 destinationChainId, uint256 priceInUsd);
    event ChainEnabled(uint256 indexed chainId, uint64 chainSelector, address linkAddress, address receiverAddress, address routerAddress);
    event ChainDisabled(uint256 indexed chainId);
    event CreateCrossSale(uint256 indexed tokenId, address indexed sellerAddress, uint256 sourceChainId, uint256 destinationChainId, uint256 priceInUsd);
    event SaleDeleted(uint256 indexed saleId, uint256 indexed tokenId);
    event Buy(uint256 indexed saleId, address indexed buyerAddress, uint256 amountPaied);
    event BuyCrossSale(uint256 indexed saleId, address indexed buyerAddress, uint256 amountPaied, address indexed sellerAddress);
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
    event ChainReceiverDeleted(uint256 indexed chainId);
    event DeCupOwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ChainReceiverAdded(uint256 indexed chainId, address indexed receiverAddress);
    event CcipCollateralSet(uint256 amount);
    //Modifiers
    /**
     * @notice Modifier to check if the amount is greater than zero
     * @dev Reverts if the amount is zero
     * @param amount The amount to check
     */

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DeCupManager__MoreThanZero();
        }
        _;
    }

    /**
     * @notice Modifier to check if the sender is the owner of a specific sale
     * @dev Reverts if the sender is not the seller of the specified sale
     * @param saleId The ID of the sale to check ownership for
     * @param chainId The chain ID where the sale exists
     */
    modifier onlySaleOwner(uint256 saleId, uint256 chainId) {
        if (s_chainIdToSaleIdToSaleOrder[chainId][saleId].sellerAddress != msg.sender) {
            revert DeCupManager__NotOwner();
        }
        _;
    }

    /**
     * @notice Initializes the DeCupManager contract
     * @dev Sets up the NFT contract reference, price feed, and cross-chain configurations
     * @param decupAddress The address of the DeCup NFT contract
     * @param priceFeedAddress The address of the Chainlink price feed contract
     * @param destinationChainIds Array of destination chain IDs to support
     * @param destinationChainSelectors Array of CCIP chain selectors for each destination chain
     * @param linkTokens Array of LINK token addresses for each destination chain
     * @param routerAddress Array of CCIP router addresses for each destination chain
     */
    constructor(
        address decupAddress,
        address priceFeedAddress,
        uint64[] memory destinationChainIds,
        uint64[] memory destinationChainSelectors,
        address[] memory linkTokens,
        address[] memory routerAddress
    ) Ownable(msg.sender) CCIPReceiver(block.chainid == 11155111 ? routerAddress[0] : routerAddress[1]) {
        s_nft = IDeCup(decupAddress);
        s_priceFeedAddress = priceFeedAddress;
        s_ccipCollateralInUsd = 5e8;

        for (uint256 i = 0; i < destinationChainIds.length; i++) {
            s_chainIdToChainSelector[destinationChainIds[i]] = destinationChainSelectors[i];
            s_chainIdToLinkAddress[destinationChainIds[i]] = linkTokens[i];
            s_chainIdToRouterAddress[destinationChainIds[i]] = routerAddress[i];
        }

        i_ccipRouter = s_chainIdToRouterAddress[block.chainid];
        i_linkToken = LinkTokenInterface(s_chainIdToLinkAddress[block.chainid]);
        i_currentChainSelector = s_chainIdToChainSelector[block.chainid];
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
     * @dev Only callable by the user who owns the collateral
     * @dev The collateral is removed from the contract and the user's balance is updated
     */
    function withdrawFunds() external nonReentrant {
        uint256 amount = s_userToCollateral[msg.sender];
        if (amount == 0) {
            revert DeCupManager__InsufficientFunds();
        }
        _removeCollateral(msg.sender, amount);
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        if (!success) {
            revert DeCupManager__TransferFailed();
        }
    }

    /**
     * @notice Transfers ownership of the DeCup NFT contract to a new owner
     * @dev Only callable by the current owner of this manager contract
     * @param newOwner The address of the new owner
     */
    function transferOwnershipOfDeCup(address newOwner) external onlyOwner {
        emit DeCupOwnershipTransferred(msg.sender, newOwner);
        s_nft.transferOwnership(newOwner);
    }

    /**
     * @notice Creates a new cross-chain sale order for a locally minted DeCup NFT
     * @dev The token must NOT be listed for sale on the target chain before creating an order
     * @dev Creates a new sale order on target chain and stores it in the mapping saleId => saleOrder (tokenId, sellerAddress, buyerAddress, networkId)
     * @dev Increments the sale ID counter and emits a SaleCreated event (saleId, tokenId, sellerAddress)
     * @dev Lists the token for sale in the NFT contract after creating the order
     * @param tokenId The ID of the token to be sold
     * @param beneficiaryAddress The address that will receive payment
     * @param destinationChainId The ID of the target chain where the sale will be created
     */
    function createCrossSale(uint256 tokenId, address beneficiaryAddress, uint256 destinationChainId, uint256 priceInUsd) external payable moreThanZero(msg.value) nonReentrant {
        // Checks
        uint256 ccipCollateralInEth = getPriceInETH(s_ccipCollateralInUsd);
        if (msg.value < ccipCollateralInEth) {
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
        emit CreateCrossSale(tokenId, msg.sender, block.chainid, destinationChainId, priceInUsd);
        s_nft.listForSale(tokenId, destinationChainId);
        string[] memory assetsInfo = s_nft.getAssetsInfo(tokenId);

        // Interactions
        //Call ccip message to execute internalfunction _createSale on destination chain

        CrossChainMessage memory messageData = CrossChainMessage({
            action: CrossChainAction.CreateSale,
            saleId: 0,
            order: Order({tokenId: tokenId, sellerAddress: msg.sender, beneficiaryAddress: beneficiaryAddress, chainId: block.chainid, priceInUsd: priceInUsd, assetsInfo: assetsInfo}),
            buyerAddress: address(0),
            isBurn: false,
            priceInUsd: 0
        });

        _sendCrossChainMessage(destinationChainId, messageData);
    }

    /**
     * @notice Sends a cross-chain message to the destination chain
     * @dev Handles CCIP message construction and fee payment
     * @param destinationChainId The ID of the destination chain
     * @param messageData The data to send to the destination chain
     */
    function _sendCrossChainMessage(uint256 destinationChainId, CrossChainMessage memory messageData) internal {
        uint64 currentChainSelector = s_chainIdToChainSelector[block.chainid];
        uint64 destinationChainSelector = s_chainIdToChainSelector[destinationChainId];
        address linkAddress = s_chainIdToLinkAddress[block.chainid];
        address ccipRouter = s_chainIdToRouterAddress[block.chainid];

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(s_chainIdToReceiverAddress[destinationChainId]), //destination chain receiver address
            //abi.encodeWithSignature("_createSale(uint256,address,uint256)", tokenId, beneficiaryAddress, chainId),
            data: abi.encode(messageData),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: s_payFeesIn == PayFeesIn.LINK ? linkAddress : address(0)
        });

        uint256 fee = IRouterClient(ccipRouter).getFee(destinationChainSelector, message); //source chain router address and destination chain selector
        bytes32 messageId;

        _removeCollateral(msg.sender, fee);

        if (s_payFeesIn == PayFeesIn.LINK) {
            // LinkTokenInterface(i_link).approve(i_router, fee);
            messageId = IRouterClient(ccipRouter).ccipSend(destinationChainSelector, message); //source chain router address and destination chain selector
        } else {
            messageId = IRouterClient(ccipRouter).ccipSend{value: fee}(destinationChainSelector, message);
        }

        emit CrossChainSent(messageId, currentChainSelector, destinationChainSelector);
    }

    /**
     * @notice Cancels a cross-chain sale order
     * @dev The collateral amount is required to cover CCIP fees for cross-chain token transfers
     * @dev Actual NFT token is minted on the same chain as the manager contract being interacted with
     * @dev Removes the token from sale on both chains and sends a cross-chain message to cancel the sale
     * @param destinationChainId The ID of the chain where the sale exists
     * @param tokenId The ID of the token to remove from sale
     */
    function cancelCrossSale(uint256 destinationChainId, uint256 tokenId) external payable nonReentrant {
        uint256 ccipCollateralInEth = getPriceInETH(s_ccipCollateralInUsd);

        if (msg.value < ccipCollateralInEth) {
            revert DeCupManager__InsufficientETH();
        }

        if (!s_nft.getIsListedForSale(tokenId)) {
            revert DeCupManager__TokenNotListedForSale();
        }

        emit CancelCrossSale(tokenId);
        emit SaleDeleted(0, tokenId);
        _addCollateral(msg.sender, msg.value);

        s_nft.removeFromSale(tokenId);
        // Call ccip message to execute internal function _cancelSale on destination chain
        CrossChainMessage memory messageData = CrossChainMessage({
            action: CrossChainAction.CancelSale,
            saleId: 0,
            order: Order({tokenId: tokenId, sellerAddress: msg.sender, beneficiaryAddress: msg.sender, chainId: destinationChainId, priceInUsd: 0, assetsInfo: new string[](0)}),
            buyerAddress: address(0),
            isBurn: false,
            priceInUsd: 0
        });

        _sendCrossChainMessage(destinationChainId, messageData);
    }

    /**
     * @notice Executes a cross-chain buy order for a DeCup NFT
     * @dev Buyer must send sufficient ETH to cover:
     *      1. The token price in ETH (converted from USD)
     *      2. CCIP fees for cross-chain message
     * @dev Records the payment amount and initiates cross-chain transfer via CCIP
     * @dev Emits Buy event on successful payment and CrossChainSent on message dispatch
     * @dev This function is called by the buyer from destination chain to purchase a DeCup NFT on source chain
     * @param saleId The ID of the sale to purchase
     * @param buyerBeneficiaryAddress The address that will receive the NFT
     * @param destinationChainId The ID of the source chain where the NFT is located
     * @param isBurn Whether to burn the token after transfer
     */
    function buyCrossSale(uint256 saleId, address buyerBeneficiaryAddress, uint256 destinationChainId, bool isBurn) external payable nonReentrant {
        //uint256 priceInETH = getPriceInETHIncludingCollateral(priceInUsd);
        Order memory saleOrder = s_chainIdToSaleIdToSaleOrder[destinationChainId][saleId];
        uint256 ccipCollateralInEth = getPriceInETH(s_ccipCollateralInUsd);
        uint256 priceInEth = getPriceInETH(saleOrder.priceInUsd);

        if (msg.value < (priceInEth + ccipCollateralInEth)) {
            revert DeCupManager__InsufficientETH();
        }

        emit BuyCrossSale(saleId, msg.sender, msg.value, saleOrder.beneficiaryAddress);
        emit SaleDeleted(saleId, saleOrder.tokenId);

        uint256 sallersPayment = msg.value - ccipCollateralInEth;
        uint256 buyersCollateral = ccipCollateralInEth;
        _addCollateral(saleOrder.beneficiaryAddress, sallersPayment);
        _addCollateral(msg.sender, buyersCollateral);
        uint256 priceInUsd = getPriceInUsd(msg.value);
        delete s_chainIdToSaleIdToSaleOrder[destinationChainId][saleId];
        delete s_chainIdToTokenIdToSaleId[destinationChainId][saleOrder.tokenId];

        // Interactions
        // Call internal ccip function to transfer token to buyer

        CrossChainMessage memory messageData =
            CrossChainMessage({action: CrossChainAction.Buy, saleId: saleId, order: saleOrder, buyerAddress: buyerBeneficiaryAddress, isBurn: isBurn, priceInUsd: priceInUsd});

        emit CrossChainDataSent(
            messageData.action,
            messageData.saleId,
            messageData.order.tokenId,
            messageData.order.sellerAddress,
            messageData.order.beneficiaryAddress,
            messageData.order.chainId,
            messageData.buyerAddress,
            messageData.isBurn,
            messageData.priceInUsd
        );
        _sendCrossChainMessage(destinationChainId, messageData);
    }

    /**
     * @notice Handles incoming CCIP messages (external interface)
     * @dev This function is called by the CCIP router and validates the sender
     * @param message The CCIP message containing the cross-chain data
     */
    function ccipReceive(Client.Any2EVMMessage memory message) external virtual override onlyRouter nonReentrant {
        _ccipReceive(message);
    }

    /**
     * @notice Internal function to process incoming CCIP messages
     * @dev Decodes the message data and executes the appropriate action
     * @param message The CCIP message containing the cross-chain data
     */
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override {
        (CrossChainMessage memory messageData) = abi.decode(message.data, (CrossChainMessage));

        emit CrossChainReceived(message.messageId, message.sourceChainSelector, s_chainIdToChainSelector[block.chainid]);
        emit CrossChainDataReceived(
            messageData.action,
            messageData.saleId,
            messageData.order.tokenId,
            messageData.order.sellerAddress,
            messageData.order.beneficiaryAddress,
            messageData.order.chainId,
            messageData.buyerAddress,
            messageData.isBurn,
            messageData.priceInUsd
        );

        if (messageData.action == CrossChainAction.CreateSale) {
            _createSale(
                messageData.order.tokenId,
                messageData.order.sellerAddress,
                messageData.order.beneficiaryAddress,
                messageData.order.chainId,
                messageData.order.priceInUsd,
                messageData.order.assetsInfo
            );
        } else if (messageData.action == CrossChainAction.CancelSale) {
            _cancelSale(messageData.order.tokenId, messageData.order.sellerAddress, messageData.order.chainId);
        } else if (messageData.action == CrossChainAction.Buy) {
            emit Buy(messageData.saleId, messageData.buyerAddress, messageData.priceInUsd);
            _buy(messageData.saleId, messageData.order.tokenId, messageData.order.sellerAddress, messageData.buyerAddress, messageData.isBurn);
        } else {
            revert DeCupManager__InvalidAction();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enables a new chain for cross-chain interactions
     * @dev Adds the chain details to the mapping chainId => chainSelector, linkAddress, receiverAddress, routerAddress
     * @param chainId The ID of the chain to enable
     * @param chainSelector The ChainSelector of the chain
     * @param linkAddress The address of the LINK token on the chain
     * @param receiverAddress The address of the receiver contract on the chain
     * @param routerAddress The address of the router contract on the chain
     */
    function enableChain(uint256 chainId, uint64 chainSelector, address linkAddress, address receiverAddress, address routerAddress) public onlyOwner nonReentrant {
        s_chainIdToChainSelector[chainId] = chainSelector;
        s_chainIdToLinkAddress[chainId] = linkAddress;
        s_chainIdToReceiverAddress[chainId] = receiverAddress;
        s_chainIdToRouterAddress[chainId] = routerAddress;
        emit ChainEnabled(chainId, chainSelector, linkAddress, receiverAddress, routerAddress);
    }

    /**
     * @notice Updates the receiver address for a chain
     * @dev Updates the receiver address in the mapping chainId => receiverAddress
     * @param chainId The ID of the chain to update
     * @param receiverAddress The new receiver address for the chain
     */
    function addChainReceiver(uint256 chainId, address receiverAddress) public onlyOwner nonReentrant {
        s_chainIdToReceiverAddress[chainId] = receiverAddress;
        emit ChainReceiverAdded(chainId, receiverAddress);
    }

    /**
     * @notice Disables a chain for cross-chain interactions
     * @dev Removes the chain details from the mapping chainId => chainSelector, linkAddress, receiverAddress, routerAddress
     * @param chainId The ID of the chain to disable
     */
    function disableChain(uint256 chainId) public onlyOwner nonReentrant {
        delete s_chainIdToChainSelector[chainId];
        delete s_chainIdToLinkAddress[chainId];
        delete s_chainIdToReceiverAddress[chainId];
        delete s_chainIdToRouterAddress[chainId];
        emit ChainDisabled(chainId);
    }

    /**
     * @notice Deletes the receiver address for a chain
     * @dev Deletes the receiver address from the mapping chainId => receiverAddress
     * @param chainId The ID of the chain to delete
     */
    function deleteChainReceiver(uint256 chainId) public onlyOwner nonReentrant {
        delete s_chainIdToReceiverAddress[chainId];
        emit ChainReceiverDeleted(chainId);
    }

    /**
     * @notice Buys a DeCup NFT on the same chain as the manager contract
     * @dev Buys a DeCup NFT from a sale order
     * @dev The buyer must send sufficient ETH to cover the price of the NFT
     * @param saleId The ID of the sale to buy
     * @param buyerBeneficiaryAddress The address that will receive the NFT
     * @param isBurn Whether to burn the NFT after transfer
     */
    function buy(uint256 saleId, address buyerBeneficiaryAddress, bool isBurn) public payable nonReentrant {
        Order memory saleOrder = s_chainIdToSaleIdToSaleOrder[block.chainid][saleId];
        // Checks
        if (saleOrder.sellerAddress == address(0)) {
            revert DeCupManager__SaleNotFound();
        }
        uint256 tokenId = saleOrder.tokenId;
        if (!s_nft.getIsListedForSale(tokenId)) {
            revert DeCupManager__TokenNotListedForSale();
        }
        if (s_nft.ownerOf(tokenId) != saleOrder.sellerAddress) {
            revert DeCupManager__NotOwner();
        }

        uint256 priceInUsd = saleOrder.priceInUsd;
        uint256 priceInETH = getPriceInETH(priceInUsd);
        if (msg.value < priceInETH) {
            revert DeCupManager__InsufficientETH();
        }
        // Effects
        emit Buy(saleId, msg.sender, priceInETH);
        emit SaleDeleted(saleId, saleOrder.tokenId);
        _addCollateral(saleOrder.beneficiaryAddress, priceInETH);

        // Interactions
        (, bool success) = _buy(saleId, saleOrder.tokenId, saleOrder.sellerAddress, buyerBeneficiaryAddress, isBurn);
        if (!success) {
            revert DeCupManager__TransferFailed();
        }
    }

    /**
     * @notice Set the CCIP collateral amount required for cross-chain transfers
     * @dev The collateral amount is required to cover CCIP fees for cross-chain token transfers
     * @dev This amount is stored in USD with 8 decimals (not wei)
     * @param amount The collateral amount in USD (with 8 decimals)
     */
    function setCcipCollateral(uint256 amount) public onlyOwner nonReentrant {
        s_ccipCollateralInUsd = amount;
        emit CcipCollateralSet(amount);
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
    function createSale(uint256 tokenId, address beneficiaryAddress) public nonReentrant {
        // Check if token is listed for sale on target chain, before call creating an order
        if (s_nft.getIsListedForSale(tokenId)) {
            revert DeCupManager__TokenListedForSale();
        }

        if (s_nft.ownerOf(tokenId) != msg.sender) {
            revert DeCupManager__NotOwner();
        }
        // Effects
        string[] memory assetsInfo = s_nft.getAssetsInfo(tokenId);

        _createSale(tokenId, msg.sender, beneficiaryAddress, block.chainid, s_nft.getTokenPriceInUsd(tokenId), assetsInfo);

        // Interactions
        s_nft.listForSale(tokenId, block.chainid);
    }

    /**
     * @notice Cancels an existing sale order
     * @dev Removes the seller address mapping for the given sale ID
     * @dev Only the seller or contract owner can cancel orders (access control should be added)
     * @param tokenId The ID of the token to cancel the sale for
     */
    function cancelSale(uint256 tokenId) public nonReentrant {
        // Checks
        uint256 saleId = s_chainIdToTokenIdToSaleId[block.chainid][tokenId];
        Order memory saleOrder = s_chainIdToSaleIdToSaleOrder[block.chainid][saleId];
        if (saleOrder.sellerAddress == address(0)) {
            revert DeCupManager__SaleNotFound();
        }

        if (!s_nft.getIsListedForSale(saleOrder.tokenId)) {
            revert DeCupManager__TokenNotListedForSale();
        }

        // Effects
        _cancelSale(tokenId, msg.sender, block.chainid);

        // Interactionss
        s_nft.removeFromSale(saleOrder.tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to transfer or burn a DeCup NFT between addresses
     * @dev Verifies token ownership before transfer
     * @param saleId The ID of the sale being executed
     * @param tokenId The ID of the NFT being transferred
     * @param sellerAddress The current owner address
     * @param buyerAddress The recipient address
     * @param isBurn Whether to burn the token after transfer
     * @return saleId The ID of the executed sale
     * @return success Whether the transfer was successful
     */
    function _buy(
        uint256 saleId,
        uint256 tokenId,
        address sellerAddress,
        address buyerAddress,
        //uint256 priceInUsd,
        bool isBurn
    ) internal returns (uint256, bool) {
        // Checks
        bool success = false;
        if (s_nft.ownerOf(tokenId) != sellerAddress) {
            revert DeCupManager__NotTokenOwner();
        }

        // Effects
        delete s_chainIdToSaleIdToSaleOrder[block.chainid][saleId];
        delete s_chainIdToTokenIdToSaleId[block.chainid][tokenId];

        // Interactions
        if (isBurn) {
            (success) = s_nft.transferAndBurn(tokenId, buyerAddress);
            if (!success) {
                revert DeCupManager__TransferFailed();
            }
        } else {
            (success) = s_nft.transfer(tokenId, buyerAddress);
            if (!success) {
                revert DeCupManager__TransferFailed();
            }
        }
        return (saleId, success);
    }

    /**
     * @notice Creates a new sale order for a DeCup NFT
     * @dev Creates a new sale order and stores it in the mapping saleId => saleOrder (tokenId, sellerAddress, buyerAddress, networkId)
     * @dev Increments the sale ID counter and emits a SaleCreated event (saleId, tokenId, sellerAddress)
     * @param tokenId The ID of the token to be sold
     * @param sellerAddress The address of the seller
     * @param beneficiaryAddress The address that will receive payment
     * @param chainId The ID of the chain where the sale is created
     * @param priceInUsd The price of the NFT in USD (with 8 decimals)
     */
    function _createSale(uint256 tokenId, address sellerAddress, address beneficiaryAddress, uint256 chainId, uint256 priceInUsd, string[] memory assetsInfo) internal {
        uint256 saleId = s_saleCounter;
        Order memory saleOrder =
            Order({tokenId: tokenId, sellerAddress: sellerAddress, beneficiaryAddress: beneficiaryAddress, chainId: chainId, priceInUsd: priceInUsd, assetsInfo: assetsInfo});
        s_chainIdToSaleIdToSaleOrder[chainId][saleId] = saleOrder;
        s_chainIdToTokenIdToSaleId[chainId][tokenId] = saleId;
        s_saleCounter++;
        emit CreateSale(saleId, tokenId, sellerAddress, block.chainid, chainId, priceInUsd);
    }

    /**
     * @notice Cancels a sale order
     * @dev Deletes the sale order from the mapping chainId => saleId => saleOrder
     * @dev Verifies the caller is the seller of the sale order
     * @dev Emits a CancelSale event (saleId)
     * @param tokenId The ID of the token to cancel the sale for
     * @param sellerAddress The address of the seller canceling the sale
     * @param chainId The chain ID where the sale was created
     */
    function _cancelSale(uint256 tokenId, address sellerAddress, uint256 chainId) internal {
        uint256 saleId = s_chainIdToTokenIdToSaleId[chainId][tokenId];
        Order memory saleOrder = s_chainIdToSaleIdToSaleOrder[chainId][saleId];
        if (saleOrder.sellerAddress != sellerAddress) {
            revert DeCupManager__NotOwner();
        }
        delete s_chainIdToSaleIdToSaleOrder[chainId][saleId];
        delete s_chainIdToTokenIdToSaleId[chainId][tokenId];
        emit CancelSale(saleId);
        emit SaleDeleted(saleId, tokenId);
    }
    /**
     * @notice Adds collateral to the contract
     * @dev Adds collateral to the contract and emits a Deposit event (user, amount)
     * @param user The address of the user adding collateral
     * @param amount The amount of collateral to add
     */

    function _addCollateral(address user, uint256 amount) internal {
        s_userToCollateral[user] += amount;
        emit Deposit(user, amount);
    }

    /**
     * @notice Removes collateral from the contract
     * @dev Removes collateral from the contract and emits a Withdraw event (user, amount)
     * @param user The address of the user removing collateral
     * @param amount The amount of collateral to remove
     */
    function _removeCollateral(address user, uint256 amount) internal {
        s_userToCollateral[user] -= amount;
        emit Withdraw(user, amount);
    }

    /*//////////////////////////////////////////////////////////////
                EXTERNAL / PUBLIC VIEW / PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the sale ID for a given token on a specific chain
     * @dev Retrieves the sale ID from the mapping s_chainIdToTokenIdToSaleId
     * @param chainId The ID of the chain where the token is listed
     * @param tokenId The ID of the token to look up
     * @return The sale ID associated with the token, or 0 if not listed
     */
    function getSaleIdByTokenId(uint256 chainId, uint256 tokenId) public view returns (uint256) {
        return s_chainIdToTokenIdToSaleId[chainId][tokenId];
    }

    /**
     * @notice Returns the current USD to ETH conversion rate
     * @dev Gets the latest price data from the Chainlink price feed
     * @return The ETH value equivalent to 1 USD (with 8 decimals)
     */
    function getEthUsdPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeedAddress);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price); // return ETH value of 1 USD
    }

    /**
     * @notice Calculates the price in ETH for a given USD amount
     * @dev Converts USD price to ETH using price feed
     * @param priceInUSD The USD price to convert to ETH (with 8 decimals)
     * @return The price in ETH (wei units)
     */
    function getPriceInETH(uint256 priceInUSD) public view returns (uint256) {
        // Convert NFT price from USD to ETH
        // priceInUSD has 8 decimals, getEthUsdPrice() has 8 decimals
        // Division cancels out decimals, so multiply by 1e18 to get wei
        uint256 nftPriceInETH = (priceInUSD * 1e18) / getEthUsdPrice();

        return nftPriceInETH;
    }

    /**
     * @notice Converts ETH amount to USD equivalent
     * @dev Converts ETH price to USD using the price feed
     * @param priceInETH The ETH amount to convert (in wei)
     * @return The equivalent USD amount (with 8 decimals)
     */
    function getPriceInUsd(uint256 priceInETH) public view returns (uint256) {
        uint256 nftPriceInUsd = (priceInETH * getEthUsdPrice()) / 1e18;
        return nftPriceInUsd;
    }
    /**
     * @notice Calculates the total price in ETH for a given USD amount including CCIP collateral
     * @dev Converts USD price to ETH using price feed and adds CCIP collateral fee
     * @param priceInUSD The USD price to convert to ETH (with 8 decimals)
     * @return The total price in ETH including collateral (wei units)
     */

    function getPriceInETHIncludingCollateral(uint256 priceInUSD) public view returns (uint256) {
        uint256 nftPriceInETH = getPriceInETH(priceInUSD);
        // Add fixed collateral amount (0.01 ether)
        return nftPriceInETH + getPriceInETH(s_ccipCollateralInUsd);
    }

    /**
     * @notice Returns the address of the DeCup NFT contract
     * @dev Returns the address of the DeCup NFT contract
     * @return The address of the DeCup NFT contract
     */
    function getDeCupAddress() public view returns (address) {
        return address(s_nft);
    }

    /**
     * @notice Returns the collateral balance of a user
     * @dev Returns the collateral balance of a user
     * @param user The address of the user
     * @return The collateral balance of the user
     */
    function balanceOf(address user) public view returns (uint256) {
        return s_userToCollateral[user];
    }

    /**
     * @notice Returns the owner of a sale
     * @dev Returns the seller address for a given sale ID and chain ID
     * @param saleId The ID of the sale
     * @param chainId The ID of the chain where the sale exists
     * @return The address of the seller
     */
    function getSaleOwner(uint256 saleId, uint256 chainId) external view returns (address) {
        return s_chainIdToSaleIdToSaleOrder[chainId][saleId].sellerAddress;
    }

    /**
     * @notice Returns the CCIP router address
     * @dev Returns the CCIP router address
     * @return The CCIP router address
     */
    function getCCIPRouter() public view returns (address) {
        return address(i_ccipRouter);
    }

    /**
     * @notice Returns the CCIP collateral in ETH
     * @dev Returns the CCIP collateral in ETH
     * @return The CCIP collateral in ETH
     */
    function getCcipCollateralInEth() public view returns (uint256) {
        return getPriceInETH(s_ccipCollateralInUsd);
    }

    /**
     * @notice Returns the price feed address
     * @dev Returns the price feed address
     * @return The price feed address
     */
    function getPriceFeedAddress() public view returns (address) {
        return s_priceFeedAddress;
    }

    /**
     * @notice Returns the sale counter
     * @dev Returns the sale counter
     * @return The sale counter
     */
    function getSaleCounter() public view returns (uint256) {
        return s_saleCounter;
    }

    /**
     * @notice Returns the CCIP collateral in USD
     * @dev Returns the CCIP collateral in USD
     * @return The CCIP collateral in USD
     */
    function getCcipCollateralInUsd() public view returns (uint256) {
        return s_ccipCollateralInUsd;
    }

    /**
     * @notice Returns the chain selector
     * @dev Returns the chain selector
     * @param chainId The ID of the chain
     * @return The chain selector
     */
    function getChainSelector(uint256 chainId) public view returns (uint64) {
        return s_chainIdToChainSelector[chainId];
    }

    /**
     * @notice Returns the link address
     * @dev Returns the link address
     * @param chainId The ID of the chain
     * @return The link address
     */
    function getLinkAddress(uint256 chainId) public view returns (address) {
        return s_chainIdToLinkAddress[chainId];
    }

    /**
     * @notice Returns the receiver address
     * @dev Returns the receiver address
     * @param chainId The ID of the chain
     * @return The receiver address
     */
    function getReceiverAddress(uint256 chainId) public view returns (address) {
        return s_chainIdToReceiverAddress[chainId];
    }

    /**
     * @notice Returns the router address
     * @dev Returns the router address
     * @param chainId The ID of the chain
     * @return The router address
     */
    function getRouterAddress(uint256 chainId) public view returns (address) {
        return s_chainIdToRouterAddress[chainId];
    }

    /**
     * @notice Returns the sale order
     * @dev Returns the sale order
     * @param chainId The ID of the chain
     * @param saleId The ID of the sale
     * @return The sale order
     */
    function getSaleOrder(uint256 chainId, uint256 saleId) public view returns (Order memory) {
        return s_chainIdToSaleIdToSaleOrder[chainId][saleId];
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
