// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {IDeCup} from "./interfaces/IDeCup.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IAny2EVMMessageReceiver} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

/**
 * @title DeCupManager
 * @notice Manages the sale and purchase of DeCup NFTs with USD-denominated pricing
 * @dev This contract acts as a marketplace for DeCup NFTs, handling order creation, cancellation, and execution
 * @dev Uses a simple price feed mechanism and charges a manager fee in USD converted to ETH
 * @author DeCup Team
 */
contract DeCupManager is Ownable, IAny2EVMMessageReceiver, ReentrancyGuard {
    // Interfaces
    /// @notice Interface to interact with the DeCup NFT contract
    IDeCup private s_nft;

    // Errors
    /// @notice Thrown when a token is not listed for sale
    error DeCupManager__TokenNotListedForSale();
    /// @notice Thrown when a token is already listed for sale
    error DeCupManager__TokenListedForSale();
    /// @notice Thrown when the caller is not the owner of the token or sale
    error DeCupManager__NotOwner();
    /// @notice Thrown when insufficient ETH is provided for the operation
    error DeCupManager__InsufficientETH();
    /// @notice Thrown when a sale with the specified ID is not found
    error DeCupManager__SaleNotFound();
    /// @notice Thrown when the user has insufficient funds for withdrawal
    error DeCupManager__InsufficientFunds();
    /// @notice Thrown when a transfer operation fails
    error DeCupManager__TransferFailed();
    /// @notice Thrown when an amount is zero but should be greater than zero
    error DeCupManager__MoreThanZero();
    /// @notice Thrown when trying to cancel a sale that is not finalized
    error DeCupManager__SaleNotFinalized();
    /// @notice Thrown when the caller is not the token owner
    error DeCupManager__NotTokenOwner();
    /// @notice Thrown when the caller is not the authorized CCIP router
    error DeCupManager__NotRouter();
    /// @notice Thrown when an invalid cross-chain action is received
    error DeCupManager__InvalidAction();

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
     */
    struct Order {
        uint256 tokenId;
        address sellerAddress;
        address beneficiaryAddress;
        uint256 chainId;
    }

    /**
     * @notice Structure representing a cross-chain message
     * @param action The type of action to perform
     * @param saleId The ID of the sale
     * @param buyerAddress The address of the buyer
     * @param isBurn Whether to burn the token after transfer
     * @param order The order details
     */
    struct CrossChainMessage {
        CrossChainAction action;
        uint256 saleId;
        address buyerAddress;
        bool isBurn;
        Order order;
    }

    // State variables
    /// @notice Collateral amount required for CCIP operations (in wei)
    uint256 public s_ccipCollateral;
    /// @notice Address of the price feed contract for ETH/USD conversion
    address public s_priceFeedAddress;
    /// @notice Counter for generating unique sale IDs
    uint256 public s_saleCounter;
    /// @notice Payment method for CCIP fees (limited to Native for simplicity)
    PayFeesIn public s_payFeesIn = PayFeesIn.Native;

    /// @notice Mapping of user addresses to their collateral balances
    mapping(address user => uint256 collateral) public s_userToCollateral;
    /// @notice Mapping of sale IDs to buyer addresses
    mapping(uint256 saleId => address buyerAddress) public s_saleIdToBuyerAddress;
    /// @notice Mapping of buyer addresses to their payment amounts for specific sales
    mapping(address buyer => mapping(uint256 => uint256)) public s_buyerPaiedAmount;
    /// @notice Mapping of chain IDs to sale IDs to sale orders
    mapping(uint256 chainId => mapping(uint256 saleId => Order saleOrder)) public s_chainIdToSaleIdToSaleOrder;
    /// @notice Mapping of chain IDs to their corresponding CCIP chain selectors
    mapping(uint256 chainId => uint64 chainSelector) public s_chainIdToChainSelector;
    /// @notice Mapping of chain IDs to their LINK token addresses
    mapping(uint256 chainId => address linkAddress) public s_chainIdToLinkAddress;
    /// @notice Mapping of chain IDs to their receiver contract addresses
    mapping(uint256 chainId => address receiverAddress) public s_chainIdToReceiverAddress;
    /// @notice Mapping of chain IDs to their CCIP router addresses
    mapping(uint256 chainId => address routerAddress) public s_chainIdToRouterAddress;

    // Events
    /// @notice Emitted when a user adds collateral to their account
    /// @param user The address of the user
    /// @param amount The amount of collateral added
    event Fund(address indexed user, uint256 amount);
    /// @notice Emitted when a user withdraws collateral from their account
    /// @param user The address of the user
    /// @param amount The amount of collateral withdrawn
    event Withdraw(address indexed user, uint256 amount);
    /// @notice Emitted when a sale is cancelled
    /// @param saleId The ID of the cancelled sale
    event CancelSale(uint256 indexed saleId);
    /// @notice Emitted when a new sale is created
    /// @param saleId The ID of the created sale
    /// @param tokenId The ID of the token being sold
    /// @param sellerAddress The address of the seller
    event CreateSale(uint256 indexed saleId, uint256 indexed tokenId, address indexed sellerAddress);
    /// @notice Emitted when a buy order is initiated
    /// @param saleId The ID of the sale
    /// @param buyerAddress The address of the buyer
    /// @param amountPaied The amount paid by the buyer
    event Buy(uint256 indexed saleId, address indexed buyerAddress, uint256 amountPaied);
    /// @notice Emitted when a buy order is finalized
    /// @param saleId The ID of the sale
    /// @param buyerAddress The address of the buyer
    /// @param amountPaied The amount paid by the buyer
    event FinalizeBuy(uint256 indexed saleId, address indexed buyerAddress, uint256 amountPaied);
    /// @notice Emitted when a cross-chain message is received
    /// @param messageId The ID of the received message
    event CrossChainReceived(bytes32 messageId);
    /// @notice Emitted when a cross-chain message is sent
    /// @param messageId The ID of the sent message
    event CrossChainSent(bytes32 messageId);

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
     * @notice Modifier to check if the sender is the CCIP router
     * @dev Reverts if the sender is not the CCIP router
     */
    modifier onlyRouter() {
        if (msg.sender != address(IRouterClient(s_chainIdToRouterAddress[block.chainid]))) {
            revert DeCupManager__NotRouter();
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
     * @dev Only callable by the user who owns the collateral
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
     * @param tokenId The ID of the token to be sold
     * @param sellerAddress The address of the seller
     * @param beneficiaryAddress The address that will receive payment
     * @param chainId The ID of the target chain where the sale will be created
     */
    function createCrossSale(uint256 tokenId, address sellerAddress, address beneficiaryAddress, uint256 chainId)
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

        CrossChainMessage memory messageData = CrossChainMessage({
            action: CrossChainAction.CreateSale,
            saleId: 0,
            order: Order({
                tokenId: tokenId,
                sellerAddress: sellerAddress,
                beneficiaryAddress: beneficiaryAddress,
                chainId: chainId
            }),
            buyerAddress: address(0),
            isBurn: false
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(s_chainIdToReceiverAddress[chainId]),
            data: abi.encode(messageData), //abi.encodeWithSignature("_createSale(uint256,address,uint256)", tokenId, beneficiaryAddress, chainId),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: s_payFeesIn == PayFeesIn.LINK ? s_chainIdToLinkAddress[chainId] : address(0)
        });

        uint256 fee =
            IRouterClient(s_chainIdToRouterAddress[chainId]).getFee(s_chainIdToChainSelector[chainId], message);

        bytes32 messageId;

        if (s_payFeesIn == PayFeesIn.LINK) {
            // LinkTokenInterface(i_link).approve(i_router, fee);
            messageId =
                IRouterClient(s_chainIdToRouterAddress[chainId]).ccipSend(s_chainIdToChainSelector[chainId], message);
        } else {
            messageId = IRouterClient(s_chainIdToRouterAddress[chainId]).ccipSend{value: fee}(
                s_chainIdToChainSelector[chainId], message
            );
        }

        emit CrossChainSent(messageId);
    }

    /**
     * @notice Cancels a cross-chain sale order
     * @dev The collateral amount is required to cover CCIP fees for cross-chain token transfers
     * @dev Actual nft token is minted on the same chain as the manager contract I interact with
     * @param saleId The ID of the sale to cancel
     * @param chainId The ID of the chain where the sale exists
     * @param tokenId The ID of the token being sold
     */
    function cancelCrossSale(uint256 saleId, uint256 chainId, uint256 tokenId) external payable nonReentrant {
        if (msg.value < s_ccipCollateral) {
            revert DeCupManager__InsufficientETH();
        }

        if (!s_nft.getIsListedForSale(tokenId)) {
            revert DeCupManager__TokenNotListedForSale();
        }

        _addCollateral(msg.sender, msg.value);
        s_nft.removeFromSale(tokenId);
        // Call ccip message to execute internal function _cancelSale on destination chain

        CrossChainMessage memory messageData = CrossChainMessage({
            action: CrossChainAction.CancelSale,
            saleId: saleId,
            order: Order({tokenId: tokenId, sellerAddress: msg.sender, beneficiaryAddress: address(0), chainId: chainId}),
            buyerAddress: address(0),
            isBurn: false
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(s_chainIdToReceiverAddress[chainId]),
            data: abi.encode(messageData), //abi.encodeWithSignature("_cancelSale(uint256,uint256)", saleId, chainId),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: s_payFeesIn == PayFeesIn.LINK ? s_chainIdToLinkAddress[chainId] : address(0)
        });

        uint256 fee =
            IRouterClient(s_chainIdToRouterAddress[chainId]).getFee(s_chainIdToChainSelector[chainId], message);

        bytes32 messageId;

        if (s_payFeesIn == PayFeesIn.LINK) {
            // LinkTokenInterface(i_link).approve(i_router, fee);
            messageId =
                IRouterClient(s_chainIdToRouterAddress[chainId]).ccipSend(s_chainIdToChainSelector[chainId], message);
        } else {
            messageId = IRouterClient(s_chainIdToRouterAddress[chainId]).ccipSend{value: fee}(
                s_chainIdToChainSelector[chainId], message
            );
        }

        emit CrossChainSent(messageId);
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
     * @param priceInUsd The price of the NFT in USD (with 8 decimals)
     * @param chainId The ID of the source chain where the NFT is located
     * @param isBurn Whether to burn the token after transfer
     */
    function buyCrossSale(uint256 saleId, uint256 priceInUsd, uint256 chainId, bool isBurn)
        external
        payable
        nonReentrant
    {
        uint256 priceInETH = getPriceInETHIncludingCollateral(priceInUsd);
        Order memory saleOrder = s_chainIdToSaleIdToSaleOrder[block.chainid][saleId];
        if (msg.value < priceInETH) {
            revert DeCupManager__InsufficientETH();
        }
        s_buyerPaiedAmount[msg.sender][saleId] = msg.value;
        s_saleIdToBuyerAddress[saleId] = msg.sender;
        emit Buy(saleId, msg.sender, priceInETH);
        // Interactions
        // Call internal ccip function to transfer token to buyer

        CrossChainMessage memory messageData = CrossChainMessage({
            action: CrossChainAction.Buy,
            saleId: saleId,
            order: saleOrder,
            buyerAddress: msg.sender,
            isBurn: isBurn
        });
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(s_chainIdToReceiverAddress[chainId]),
            data: abi.encode(messageData),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: s_payFeesIn == PayFeesIn.LINK ? s_chainIdToLinkAddress[chainId] : address(0)
        });

        uint256 fee =
            IRouterClient(s_chainIdToRouterAddress[chainId]).getFee(s_chainIdToChainSelector[chainId], message);

        bytes32 messageId;

        if (s_payFeesIn == PayFeesIn.LINK) {
            // LinkTokenInterface(i_link).approve(i_router, fee);
            messageId =
                IRouterClient(s_chainIdToRouterAddress[chainId]).ccipSend(s_chainIdToChainSelector[chainId], message);
        } else {
            messageId = IRouterClient(s_chainIdToRouterAddress[chainId]).ccipSend{value: fee}(
                s_chainIdToChainSelector[chainId], message
            );
        }

        emit CrossChainSent(messageId);
    }

    /**
     * @notice Receives a cross-chain message
     * @dev This function is called by CCIP router when receiving cross-chain messages
     * @param message The cross-chain message containing action details and parameters
     */
    function ccipReceive(Client.Any2EVMMessage calldata message) external override onlyRouter nonReentrant {
        // Your implementation here
        // This function is called by CCIP router when receiving cross-chain messages
        CrossChainMessage memory messageData = abi.decode(message.data, (CrossChainMessage));

        if (messageData.action == CrossChainAction.CreateSale) {
            _createSale(
                messageData.order.tokenId,
                messageData.order.sellerAddress,
                messageData.order.beneficiaryAddress,
                messageData.order.chainId
            );
        } else if (messageData.action == CrossChainAction.CancelSale) {
            _cancelSale(messageData.order.tokenId, messageData.order.sellerAddress, messageData.order.chainId);
        } else if (messageData.action == CrossChainAction.Buy) {
            _buy(
                messageData.saleId,
                messageData.order.tokenId,
                messageData.order.sellerAddress,
                messageData.buyerAddress,
                messageData.isBurn
            );
        } else {
            revert DeCupManager__InvalidAction();
        }

        emit CrossChainReceived(message.messageId);
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
    function createSale(uint256 tokenId, address beneficiaryAddress) public nonReentrant {
        // Check if token is listed for sale on target chain, before call creating an order
        if (s_nft.getIsListedForSale(tokenId)) {
            revert DeCupManager__TokenListedForSale();
        }

        if (s_nft.ownerOf(tokenId) != msg.sender) {
            revert DeCupManager__NotOwner();
        }
        // Effects
        //address sellerAddress = beneficiaryAddress == address(0) ? s_nft.ownerOf(tokenId) : beneficiaryAddress;
        _createSale(tokenId, msg.sender, beneficiaryAddress, block.chainid);

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
        Order memory saleOrder = s_chainIdToSaleIdToSaleOrder[block.chainid][saleId];
        if (saleOrder.sellerAddress == address(0)) {
            revert DeCupManager__SaleNotFound();
        }

        if (!s_nft.getIsListedForSale(saleOrder.tokenId)) {
            revert DeCupManager__TokenNotListedForSale();
        }

        // Effects
        _cancelSale(saleId, msg.sender, block.chainid);

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
    function _buy(uint256 saleId, uint256 tokenId, address sellerAddress, address buyerAddress, bool isBurn)
        internal
        returns (uint256, bool)
    {
        bool success = false;
        if (s_nft.ownerOf(tokenId) != sellerAddress) {
            revert DeCupManager__NotTokenOwner();
        }
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
     */
    function _createSale(uint256 tokenId, address sellerAddress, address beneficiaryAddress, uint256 chainId)
        internal
    {
        uint256 saleId = s_saleCounter;
        Order memory saleOrder = Order({
            tokenId: tokenId,
            sellerAddress: sellerAddress,
            beneficiaryAddress: beneficiaryAddress,
            chainId: chainId
        });
        s_chainIdToSaleIdToSaleOrder[chainId][saleId] = saleOrder;
        s_saleCounter++;
        emit CreateSale(saleId, tokenId, sellerAddress);
    }

    /**
     * @notice Cancels a sale order
     * @dev Deletes the sale order from the mapping chainId => saleId => saleOrder
     * @dev Verifies the caller is the seller of the sale order
     * @dev Verifies the sale has not been finalized (no buyer assigned)
     * @dev Emits a SaleCanceled event (saleId)
     * @param saleId The ID of the sale to cancel
     * @param sellerAddress The address of the seller canceling the sale
     * @param chainId The chain ID where the sale was created
     */
    function _cancelSale(uint256 saleId, address sellerAddress, uint256 chainId) internal {
        Order memory saleOrder = s_chainIdToSaleIdToSaleOrder[chainId][saleId];
        if (saleOrder.sellerAddress != sellerAddress) {
            revert DeCupManager__NotOwner();
        }
        if (s_saleIdToBuyerAddress[saleId] != address(0)) {
            revert DeCupManager__SaleNotFinalized();
        }
        delete s_chainIdToSaleIdToSaleOrder[chainId][saleId];
        emit CancelSale(saleId);
    }

    /**
     * @notice Finalizes a buy order for a DeCup NFT
     * @dev Transfers the token to the buyer and releases the funds to the seller
     * @dev This function is supposed to be called by CCIP in response to the CCIP message call
     * @param saleId The ID of the sale to finalize
     * @param chainId The ID of the chain where the sale exists
     */
    function _finalizeBuy(uint256 saleId, uint64 chainId) internal {
        Order memory saleOrder = s_chainIdToSaleIdToSaleOrder[chainId][saleId];
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
     * @param user The address of the user adding collateral
     * @param amount The amount of collateral to add
     */
    function _addCollateral(address user, uint256 amount) internal {
        s_userToCollateral[user] += amount;
        emit Fund(user, amount);
    }

    /**
     * @notice Removes collateral from the contract
     * @dev Removes collateral from the contract and emits a Withdraw event (user, amount)
     * @param user The address of the user removing collateral
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
     * @notice Calculates the total price in ETH for a given USD amount including CCIP collateral
     * @dev Converts USD price to ETH using price feed and adds CCIP collateral fee
     * @param priceInUSD The USD price to convert to ETH (with 8 decimals)
     * @return The total price in ETH including collateral (wei units)
     */
    function getPriceInETHIncludingCollateral(uint256 priceInUSD) public view returns (uint256) {
        uint256 nftPriceInETH = getPriceInETH(priceInUSD);
        // Add fixed collateral amount (0.01 ether)
        return nftPriceInETH + s_ccipCollateral;
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
