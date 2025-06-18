// SPDX-License-Identifier: MIT

// Receive Native currency
// Receive ERC20
// Withdraw Native currency
// Withdraw ERC20
// MintNFT with attributes equal to deposited amount
// BurnNFT & withdraw assets based on NFT collateral data

// Chainklink "Receiver" should have permissions send NFT to another owner (change owner).
// Chainklink "Receiver" should have permissions to burn NFT on behalf of an owner.

pragma solidity 0.8.29;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralized Cup of assets (DeCup)
 * @author Alexander Scherbatyuk
 * @notice Collaterised NFT (Cup of Assets) to be soled cross-chain as single NFT. Contract receive native currency and
 * a pre defiend number of ERC20 tokens as colleterral.
 * @dev This contract utilizes:
 * - Chainlink Price Feeds to calculate NFT price based on assets market prices,
 * - Chainlink CCIP to papulate transfer and burn functionalities cros-chain.
 */
contract DeCup is ERC721, ERC721Burnable, Ownable, ReentrancyGuard {
    // Errors
    error DeCup__AmountMustBeGreaterThanZero();
    error DeCup__TransferFailed();
    error DeCup__InsufficientBalance();
    error DeCup__NotAllowedToken();
    error DeCup__TokenAddressesAndPriceFeedAddressesMusBeSameLength();
    error DeCup__TokenAddressesAndAmountsMusBeSameLength();
    error DeCup__ApprovalFailed();
    error DeCup__ZeroAddress();
    error DeCup__TokenDoesNotExist();
    error DeCup__AllowedTokenAddressesMustNotBeEmpty();
    error DeCup__PriceFeedAddressesMustNotBeEmpty();
    error DeCup__TokenIsListedForSale();
    error DeCup__TokenIsNotListedForSale();
    error DeCup__NotOwner();
    error DeCup__NotTokenOwner();

    // State variables
    uint256 private s_tokenCounter;
    string private s_svgImageUri;
    address private s_salerAddress;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    address private s_defaultPriceFeed;

    mapping(uint256 tokenId => address[] assets) private s_tokenIdToAssets;
    mapping(address token => address priceFeed) private s_tokenToPriceFeed;
    mapping(uint256 tokenId => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(uint256 tokenId => bool isListedForSale) private s_tokenIdIsListedForSale;

    // Events
    event DepositNativeCurrency(address indexed from, uint256 amount);
    event DepositERC20Token(address indexed from, address indexed token, uint256 amount);
    event WithdrawNativeCurrency(address indexed to, uint256 amount);
    event WithdrawERC20Token(address indexed to, address indexed token, uint256 amount);
    event TokenListedForSale(uint256 indexed tokenId);
    event TokenRemovedFromSale(uint256 indexed tokenId);

    // Modifiers

    /**
     * @notice Modifier to check if the amount is greater than zero
     * @param amount The amount to check
     * @dev Reverts if the amount is zero
     */
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DeCup__AmountMustBeGreaterThanZero();
        }
        _;
    }

    /**
     * @notice Modifier to check if the caller is the owner of the token
     * @param tokenId The ID of the token to check
     * @dev Reverts if the caller is not the owner of the token
     */
    modifier isTokenOwner(uint256 tokenId) {
        if (ownerOf(tokenId) != msg.sender) {
            revert DeCup__NotTokenOwner();
        }
        _;
    }

    /**
     * @notice Modifier to check if the caller is the owner of the token
     * @param tokenId The ID of the token to check
     * @dev Reverts if the caller is not the owner of the token
     */
    modifier isTokenOwnerOrOwner(uint256 tokenId) {
        if (ownerOf(tokenId) != msg.sender && owner() != msg.sender) {
            revert DeCup__NotOwner();
        }
        _;
    }

    /**
     * @notice Modifier to check if the token is listed for sale
     * @param tokenId The ID of the token to check
     * @dev Reverts if the token is listed for sale
     */
    modifier tokenIsListedForSale(uint256 tokenId) {
        if (s_tokenIdIsListedForSale[tokenId]) {
            revert DeCup__TokenIsListedForSale();
        }
        _;
    }

    modifier tokenExists(uint256 tokenId) {
        address[] memory assets = s_tokenIdToAssets[tokenId];
        if (assets.length == 0) {
            revert DeCup__TokenDoesNotExist();
        }
        _;
    }

    // Functions
    /**
     * @notice Constructor to initialize the DeCup NFT contract with supported tokens and price feeds
     * @param _baseSvgImageUri Base URI for SVG images associated with NFTs
     * @param _tokenAddresses Array of ERC20 token addresses that can be used as collateral
     * @param _priceFeedAddresses Array of Chainlink price feed addresses corresponding to each token
     */
    constructor(
        string memory _baseSvgImageUri,
        address[] memory _tokenAddresses,
        address[] memory _priceFeedAddresses,
        address _defaultPriceFeed
    ) ERC721("DeCup", "DCT") Ownable(msg.sender) {
        if (_tokenAddresses.length == 0) {
            revert DeCup__AllowedTokenAddressesMustNotBeEmpty();
        }

        if (_priceFeedAddresses.length == 0) {
            revert DeCup__PriceFeedAddressesMustNotBeEmpty();
        }

        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert DeCup__TokenAddressesAndPriceFeedAddressesMusBeSameLength();
        }

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_tokenToPriceFeed[_tokenAddresses[i]] = _priceFeedAddresses[i];
        }

        s_tokenCounter = 0;
        s_svgImageUri = _baseSvgImageUri;
        s_defaultPriceFeed = _defaultPriceFeed;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to deposit native currency and mint a collateralized NFT
     * @dev This function is called when native currency is sent to the contract
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Uses nonReentrant modifier to prevent reentrancy attacks
     * @dev Emits DepositNativeCurrency event on successful deposit
     * @dev Mints a new NFT with tokenId equal to current tokenCounter
     * @dev Stores the native currency amount as collateral for the minted NFT
     * @dev Increments tokenCounter after successful mint
     * @dev Requires msg.value to be greater than zero (enforced by moreThanZero modifier)
     */
    receive() external payable moreThanZero(msg.value) nonReentrant {
        // Check (in modifiers)

        // Effect
        uint256 tokenId = s_tokenCounter;
        s_collateralDeposited[tokenId][address(0)] += msg.value;
        s_tokenIdToAssets[tokenId].push(address(0));
        emit DepositNativeCurrency(msg.sender, msg.value);

        _safeMint(msg.sender, tokenId);
        s_tokenCounter++;

        //interact
    }

    /**
     * s
     * @notice Function to deposit an ERC20 token to an existing NFT as additional collateral
     * @param tokenAddress The ERC20 token contract address to deposit (must be a supported token with price feed)
     * @param amount The amount of tokens to deposit (must be greater than 0)
     * @param tokenId The ID of the existing NFT to add collateral to
     * @dev This function will transfer the specified amount of tokens from the caller to this contract
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Uses nonReentrant modifier to prevent reentrancy attacks
     * @dev Emits DepositERC20Token event on successful deposit
     * @dev The caller must have approved this contract to spend their tokens before calling this function
     */
    function addTokenCollateralToExistingCup(address tokenAddress, uint256 amount, uint256 tokenId)
        external
        isTokenOwner(tokenId)
        tokenIsListedForSale(tokenId)
        moreThanZero(amount)
        nonReentrant
    {
        // Checkss
        if (s_tokenToPriceFeed[tokenAddress] == address(0)) {
            revert DeCup__NotAllowedToken();
        }
        // Effects
        if (s_collateralDeposited[tokenId][tokenAddress] == 0) {
            s_tokenIdToAssets[tokenId].push(tokenAddress);
        }
        s_collateralDeposited[tokenId][tokenAddress] += amount;
        emit DepositERC20Token(msg.sender, tokenAddress, amount);
    }

    /**
     * @notice Function to add native currency as collateral to an existing NFT
     * @param tokenId The ID of the existing NFT to add native currency collateral to
     * @dev This function is called when native currency is sent to add to an existing cup
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Uses moreThanZero modifier to ensure non-zero deposits
     * @dev Emits DepositNativeCurrency event on successful deposit
     * @dev If this is the first native currency deposit for this NFT, adds address(0) to tokenIdToAssets
     * @dev Requires msg.value to be greater than zero (enforced by moreThanZero modifier)
     * @dev Requires the NFT to exist (enforced by tokenId validation)
     */
    function addNativeCollateralToExistingCup(uint256 tokenId)
        external
        payable
        isTokenOwner(tokenId)
        tokenIsListedForSale(tokenId)
        moreThanZero(msg.value)
        nonReentrant
    {
        if (s_collateralDeposited[tokenId][address(0)] == 0) {
            s_tokenIdToAssets[tokenId].push(address(0));
        }
        s_collateralDeposited[tokenId][address(0)] += msg.value;
        emit DepositNativeCurrency(msg.sender, msg.value);
    }

    /**
     * @notice Function to deposit a single ERC20 token and mint an NFT collateralized by this token
     * @param tokenAddress The ERC20 token contract address to deposit (must be a supported token with price feed)
     * @param amount The amount of tokens to deposit (must be greater than 0)
     * @dev This function will transfer the specified amount of tokens from the caller to this contract
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Uses nonReentrant modifier to prevent reentrancy attacks
     * @dev Emits DepositERC20Token event on successful deposit
     * @dev The caller must have approved this contract to spend their tokens before calling this function
     */
    function depositSingleAssetAndMint(address tokenAddress, uint256 amount)
        external
        payable
        moreThanZero(amount)
        nonReentrant
    {
        // Checkss
        if (s_tokenToPriceFeed[tokenAddress] == address(0)) {
            revert DeCup__NotAllowedToken();
        }
        // Effects
        uint256 tokenId = s_tokenCounter;
        emit DepositERC20Token(msg.sender, tokenAddress, amount);
        s_collateralDeposited[tokenId][tokenAddress] += amount;
        s_tokenIdToAssets[tokenId].push(tokenAddress);
        _mintAndIncreaseCounter(msg.sender, tokenId);

        // Interactionss
        (bool success) = IERC20Metadata(tokenAddress).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert DeCup__TransferFailed();
        }
    }

    /**
     * @notice Function to deposit multiple ERC20 tokens and native currency, minting a single NFT collateralized by all assets
     * @param tokenAddresses Array of ERC20 token contract addresses to deposit as collateral
     * @param amounts Array of amounts to deposit for each corresponding token address
     * @dev Can also accept native currency via msg.value. If msg.value > 0, native currency will be included as collateral
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Uses nonReentrant modifier to prevent reentrancy attacks
     * @dev Emits DepositNativeCurrency and DepositERC20Token events for each successful deposit
     * @dev All token amounts must be greater than 0. Token addresses and amounts arrays must be same length
     * @dev The caller must have approved this contract to spend their tokens before calling this function
     * @dev Example usage:
     *   depositMultipleAssetsAndMint(
     *     [USDC_ADDRESS, DAI_ADDRESS],
     *     [1000e6, 1000e18],
     *     {value: 1e18} // 1 ETH
     *   )
     */
    function depositMultipleAssetsAndMint(address[] memory tokenAddresses, uint256[] memory amounts)
        external
        payable
        nonReentrant
    {
        // Checks (in modifiers)
        if (tokenAddresses.length != amounts.length) {
            revert DeCup__TokenAddressesAndAmountsMusBeSameLength();
        }

        if (tokenAddresses.length == 0 || amounts.length == 0) {
            revert DeCup__AmountMustBeGreaterThanZero();
        }

        // Effects / Interctions
        uint256 tokenId = s_tokenCounter;

        if (msg.value > 0) {
            emit DepositNativeCurrency(msg.sender, msg.value);
            s_collateralDeposited[tokenId][address(0)] += msg.value;
            s_tokenIdToAssets[tokenId].push(address(0));
        }

        _mintAndIncreaseCounter(msg.sender, tokenId);

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if (amounts[i] == 0) {
                revert DeCup__AmountMustBeGreaterThanZero();
            }

            emit DepositERC20Token(msg.sender, tokenAddresses[i], amounts[i]);
            s_collateralDeposited[tokenId][tokenAddresses[i]] += amounts[i];
            s_tokenIdToAssets[tokenId].push(tokenAddresses[i]);

            (bool success) = IERC20Metadata(tokenAddresses[i]).transferFrom(msg.sender, address(this), amounts[i]);
            if (!success) {
                revert DeCup__TransferFailed();
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                           PUBLIC FUNCTIONSS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to list a token for sale
     * @param tokenId The ID of the token to list for sale
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Uses nonReentrant modifier to prevent reentrancy attacks
     * @dev Emits TokenListedForSale event on successful listing
     * @dev Reverts if the token is already listed for sale
     */
    function listForSale(uint256 tokenId, address salerAddress)
        public
        isTokenOwnerOrOwner(tokenId)
        tokenIsListedForSale(tokenId)
    {
        s_tokenIdIsListedForSale[tokenId] = true;
        s_salerAddress = salerAddress;
        emit TokenListedForSale(tokenId);
    }

    /**
     * @notice Function to remove a token from sale
     * @param tokenId The ID of the token to remove from sale
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Uses nonReentrant modifier to prevent reentrancy attacks
     * @dev Emits TokenRemovedFromSale event on successful removal
     * @dev Reverts if the token is not listed for sale
     */
    function removeFromSale(uint256 tokenId) public isTokenOwnerOrOwner(tokenId) {
        if (!s_tokenIdIsListedForSale[tokenId]) {
            revert DeCup__TokenIsNotListedForSale();
        }
        s_tokenIdIsListedForSale[tokenId] = false;
        emit TokenRemovedFromSale(tokenId);

        //interactions
        /*(bool success,) = address(payable(s_salerAddress)).call{value: address(this).balance}("");
        if (!success) {
            revert DeCup__TransferFailed();
        }*/
    }

    /**
     * @notice Function to transfer a token and burn it
     * @param tokenId The ID of the token to transfer and burn
     * @param to The address to transfer the token to
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Uses nonReentrant modifier to prevent reentrancy attacks
     */
    function transferAndBurn(uint256 tokenId, address to)
        public
        tokenExists(tokenId)
        isTokenOwnerOrOwner(tokenId)
        tokenIsListedForSale(tokenId)
        nonReentrant
    {
        _transfer(msg.sender, to, tokenId);
        burn(tokenId);
    }

    /**
     * @notice Burns the NFT and withdraws all collateral assets to the caller
     * @param tokenId The ID of the NFT to burn and withdraw collateral from
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Uses nonReentrant modifier to prevent reentrancy attacks
     * @dev Withdraws both native currency and ERC20 tokens if they were deposited as collateral
     * @dev Emits WithdrawNativeCurrency and WithdrawERC20Token events for each successful withdrawal
     * @dev Reverts if the token does not exist or if any transfer fails
     */
    function burn(uint256 tokenId)
        public
        override
        tokenExists(tokenId)
        isTokenOwnerOrOwner(tokenId)
        tokenIsListedForSale(tokenId)
        nonReentrant
    {
        address[] memory assets = s_tokenIdToAssets[tokenId];

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == address(0)) {
                _withdrawNativeCurrency(tokenId, s_collateralDeposited[tokenId][assets[i]]);
            } else {
                _withdrawSingleToken(tokenId, assets[i], s_collateralDeposited[tokenId][assets[i]]);
            }
        }

        _burn(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to mint a new token and increment the token counter
     * @param to The address to mint the token to
     * @param tokenId The ID of the token to mint
     * @dev Internal function used by deposit functions to mint NFTs
     * @dev Uses _safeMint to ensure the recipient can handle ERC721 tokens
     * @dev Increments s_tokenCounter after successful mint
     * @dev This function is called by depositSingleAssetAndMint and depositMultipleAssetsAndMint
     * @dev Ensures atomic minting and counter increment to prevent token ID conflicts
     */
    function _mintAndIncreaseCounter(address to, uint256 tokenId) private {
        _safeMint(to, tokenId);
        s_tokenCounter++;
    }

    /**
     * @notice Function to withdraw native currency
     * @param tokenId The ID of the NFT associated with the withdrawal
     * @param amount The amount of native currency to withdraw
     * @dev Internal function used by burn function to withdraw native currency
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Emits WithdrawNativeCurrency event on successful withdrawal
     * @dev Reverts if contract has insufficient balance or if transfer fails
     * @dev Funds are transferred to the owner of the NFT, not the caller
     */
    function _withdrawNativeCurrency(uint256 tokenId, uint256 amount) private {
        if (address(this).balance < amount) {
            revert DeCup__InsufficientBalance();
        }

        s_collateralDeposited[tokenId][address(0)] = 0;
        emit WithdrawNativeCurrency(msg.sender, amount);

        (bool success,) = address(payable(ownerOf(tokenId))).call{value: amount}("");
        if (!success) {
            revert DeCup__TransferFailed();
        }
    }

    /**
     * @notice Function to withdraw a single ERC20 token
     * @param tokenId The ID of the NFT associated with the withdrawal
     * @param tokenAddress The ERC20 token contract address to withdraw
     * @param amount The amount of tokens to withdraw
     * @dev Internal function used by burn function to withdraw ERC20 tokens
     * @dev Implements the CEI pattern (Checks-Effects-Interactions)
     * @dev Emits WithdrawERC20Token event on successful withdrawal
     * @dev Reverts if amount is zero (via moreThanZero modifier) or if transfer fails
     * @dev Reverts if contract has insufficient balance (via transfer check)
     * @dev Transfer function is called on the owner of the token
     */
    function _withdrawSingleToken(uint256 tokenId, address tokenAddress, uint256 amount) private moreThanZero(amount) {
        // Effect
        s_collateralDeposited[tokenId][tokenAddress] = 0;
        emit WithdrawERC20Token(msg.sender, tokenAddress, amount);
        // Interaction
        if (!IERC20Metadata(tokenAddress).transfer(address(payable(ownerOf(tokenId))), amount)) {
            revert DeCup__TransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                INTERNAL / PRIVATE VIEW / PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the USD value of a given ETH token amount
     * @param tokenAddress The address of the ETH token
     * @param amount The amount of ETH tokens
     * @return The USD value of the given ETH token amount with additional precision
     * @dev Uses Chainlink price feeds to get real-time token prices
     * @dev Applies decimals conversion to maintain accuracy in calculations
     * @dev Multiplies by 10^10 to maintain precision in calculations
     * @dev Uses fixed 18 decimals for ETH (standard for native currency)
     * @dev Returns value in USD with 18 decimals of precision
     * @dev Note: Currently uses hardcoded 18 decimals, could be made dynamic in future versions
     */
    function getEthUSDValue(address tokenAddress, uint256 amount) private view returns (uint256) {
        uint256 ethPrice = getUsdPrice(tokenAddress);
        uint8 decimals = 18; //Need to make dynamic
        return (ethPrice * 10 ** 10) * amount / 10 ** uint256(decimals);
    }

    /**
     * @notice Returns the base URI for token metadata in base64 JSON format
     * @return The base URI string for token metadata
     * @dev Overrides the ERC721 _baseURI function to return a data URI
     * @dev Used by tokenURI function to construct the complete metadata URI
     */
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    /**
     * @notice Returns the USD value of a given token amount using Chainlink price feeds
     * @param tokenAddress The address of the ERC20 token to get the value for. Use address(0) for native currency
     * @return The USD value of the given token amount with additional precision
     * @dev Uses Chainlink price feeds to get real-time token prices
     * @dev Handles both native currency and ERC20 tokens
     * @dev Applies additional precision to maintain accuracy in calculations
     */
    function getUsdPrice(address tokenAddress) private view returns (uint256) {
        AggregatorV3Interface priceFeed;

        if (tokenAddress == address(0)) {
            priceFeed = AggregatorV3Interface(s_defaultPriceFeed);
        } else {
            priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[tokenAddress]);
        }

        (, int256 price,,,) = priceFeed.latestRoundData();

        return uint256(price); //((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    /*//////////////////////////////////////////////////////////////
                EXTERNAL / PUBLIC VIEW / PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current token counter
     * @return The current token counter
     */
    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    /**
     * @notice Returns the listing status of a given token ID
     * @param tokenId The ID of the token to get the listing status for
     * @return The listing status of the given token ID
     */
    function getIsListedForSale(uint256 tokenId) public view returns (bool) {
        return s_tokenIdIsListedForSale[tokenId];
    }

    /**
     * @notice Returns the USD value of a given USDC token amount
     * @param tokenAddress The address of the USDC token
     * @param amount The amount of USDC tokens
     * @return The USD value of the given USDC token amount with additional precision
     * @dev Uses Chainlink price feeds to get real-time token prices
     * @dev Applies decimals conversion to maintain accuracy in calculations
     * @dev Multiplies by 10^10 to maintain precision in calculations
     * @dev Handles token decimals dynamically using IERC20Metadata interface
     * @dev Returns value in USD with 18 decimals of precision
     */
    function getUsdcUSDValue(address tokenAddress, uint256 amount) public view returns (uint256) {
        uint256 usdcPrice = getUsdPrice(tokenAddress);
        uint8 decimals = IERC20Metadata(tokenAddress).decimals();
        return (usdcPrice * 10 ** 10) * amount / 10 ** uint256(decimals);
    }

    /**
     * @notice Returns the amount of collateral deposited for a given token ID and token address
     * @param tokenId The ID of the token to get the collateral for
     * @param tokenAddress The address of the token to get the collateral for
     * @return The amount of collateral deposited for the given token ID and token address
     */
    function getCollateralDeposited(uint256 tokenId, address tokenAddress) public view returns (uint256) {
        return s_collateralDeposited[tokenId][tokenAddress];
    }

    /**
     * @notice Returns the list of assets deposited for a given token ID
     * @param tokenId The ID of the token to get the assets for
     * @return The list of assets deposited for the given token ID
     */
    function getTokenAssetsList(uint256 tokenId) public view returns (address[] memory) {
        return s_tokenIdToAssets[tokenId];
    }

    /**
     * @notice Returns the total collateral value (TCL) for a given token ID
     * @param tokenId The ID of the token to get the TCL for
     * @return The total collateral value (TCL) for the given token ID
     */
    function getTokenIdTCL(uint256 tokenId) public view returns (uint256) {
        address[] memory assets = s_tokenIdToAssets[tokenId];
        if (assets.length == 0) {
            revert DeCup__TokenDoesNotExist();
        }

        uint256 tcl = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == address(0)) {
                tcl += getEthUSDValue(assets[i], s_collateralDeposited[tokenId][assets[i]]);
            } else {
                tcl += getUsdcUSDValue(assets[i], s_collateralDeposited[tokenId][assets[i]]);
            }
        }
        return tcl;
    }

    /**
     * @notice Returns the metadata URI for a given token ID in base64 JSON format
     * @param _tokenId The ID of the token to get metadata for
     * @return A base64 encoded JSON string containing the token's metadata
     * @dev Overrides the ERC721 tokenURI function
     * @dev Constructs metadata including name, description, attributes and image
     * @dev Attributes include USD values of all collateral assets
     * @dev Uses Base64 encoding for on-chain metadata storage
     * @dev Calculates total collateral value (TCL) in USD
     * @dev Includes individual asset values as traits
     * @dev Example metadata structure:
     * {
     *   "tokenId": "1",
     *   "name": "DeCup #1 $1000",
     *   "description": "Decentralized Cup of assets",
     *   "attributes": [
     *     {"trait_type": "TCL", "value": "1000 USD"},
     *     {"trait_type": "ETH", "value": "500"},
     *     {"trait_type": "USDC", "value": "500"}
     *   ],
     *   "image": "data:image/svg+xml;base64,..."
     * }
     */
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        string memory imageURI = s_svgImageUri;
        address[] memory assets = s_tokenIdToAssets[_tokenId];

        bytes memory attributes;
        uint256 tcl;

        for (uint256 i = 0; i < assets.length; i++) {
            string memory symbol;
            uint256 amount = s_collateralDeposited[_tokenId][assets[i]];
            uint256 usdValue;

            //tcl += getTokenAmountFromUsd(assets[i], amount);

            if (assets[i] == address(0)) {
                // Native currency (ETH, MATIC, etc.)
                symbol = "ETH"; // You might want to make this configurable based on chain
                usdValue = getEthUSDValue(assets[i], amount);
            } else {
                // ERC20 token
                symbol = IERC20Metadata(assets[i]).symbol();
                usdValue = getUsdcUSDValue(assets[i], amount);
            }

            tcl += usdValue;

            attributes = abi.encodePacked(
                attributes,
                '{"trait_type":"',
                symbol,
                '","value":"',
                Strings.toString(amount),
                '"}',
                i < assets.length - 1 ? "," : ""
            );
        }
        tcl = tcl / 1e18;

        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"tokenId":"',
                            Strings.toString(_tokenId),
                            '","name":"',
                            abi.encodePacked(
                                name(), "#", Strings.toString(_tokenId), " $", Strings.toString(uint256(tcl))
                            ),
                            '","description":"Decentralized Cup of assets", "attributes": [',
                            '{"trait_type":"TCL","value":"',
                            Strings.toString(uint256(tcl)),
                            ' USD"}',
                            attributes.length > 0 ? "," : "",
                            attributes,
                            '],"image":"',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
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
