// SPDX-License-Identifier: MIT

// Recieve Native currency
// Receive ERC20
// Withdraw Native currency
// Withdraw ERC20
// MintNFT with attributes equal to deposited emount
// BurnNFT witdraw assets based on NFT attributes

// Chainklink "Receiver" should have permissions send NFT to another owner (change owner).
// Chainklink "Receiver" should have permissions to burn NFT on behalf of an owner.

pragma solidity ^0.8.29;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title Decentralized Cup of assets (DeCup)
 * @author Alexander Scherbatyuk
 * @notice Collaterised NFT (Cup of Assets) to be soled cross-chain as single NFT. Contract receive native currency and
 * a pre defiend number of ERC20 tokens as colleterral.
 * @dev This contract utilizes:
 * - Chainlink Price Feeds to calculate NFT price based on assets market prices,
 * - Chainlink CCIP to papulate transfer and burn functionalities cros-chain.
 */
contract DeCup is ERC721, ERC721Burnable, ReentrancyGuard {
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

    // State variables
    uint256 private s_tokenCounter;
    string private s_svgImageUri;

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    address private s_defaultPriceFeed;

    mapping(uint256 tokenId => address[] assets) private s_tokenIdToAssets;
    mapping(address token => address priceFeed) private s_tokenToPriceFeed;
    mapping(uint256 tokenId => mapping(address token => uint256 amount)) private s_collateralDeposited;

    // Events
    event DepositeNativeCurrency(address indexed from, uint256 amount);
    event DepositeERC20Token(address indexed from, address indexed token, uint256 amount);
    event WithdrawNativeCurrency(address indexed to, uint256 amount);
    event WithdrawERC20Token(address indexed to, address indexed token, uint256 amount);

    // Modifiers
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DeCup__AmountMustBeGreaterThanZero();
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
    ) ERC721("DeCup", "DCT") {
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
     * @notice Function to deposit native currency, and mint a collateralized with native currency NFT
     */
    receive() external payable moreThanZero(msg.value) nonReentrant {
        // Check (in modifiers)

        // Effect
        uint256 tokenId = s_tokenCounter;
        emit DepositeNativeCurrency(msg.sender, msg.value);
        s_collateralDeposited[tokenId][address(0)] += msg.value;
        s_tokenIdToAssets[tokenId].push(address(0));
        _safeMint(msg.sender, tokenId);
        s_tokenCounter++;

        //interact
    }

    /**
     * @notice Function to deposit a single ERC20 token and mint an NFT collateralized by this token
     * @param tokenAddress The ERC20 token contract address to deposit (must be a supported token with price feed)
     * @param amount The amount of tokens to deposit (must be greater than 0)
     * @dev This function will transfer the specified amount of tokens from the caller to this contract
     * and mint a new NFT representing the deposited collateral. The caller must have approved this contract
     * to spend their tokens before calling this function.
     */
    function depositeSingleTokenAndMint(address tokenAddress, uint256 amount)
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
        emit DepositeERC20Token(msg.sender, tokenAddress, amount);
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
     * @dev Can also accept native currency via msg.value. If msg.value > 0, native currency will be included as collateral.
     * All token amounts must be greater than 0. Token addresses and amounts arrays must be same length.
     */
    function depositeMultipleAssetsAndMint(address[] memory tokenAddresses, uint256[] memory amounts)
        external
        payable
        nonReentrant
    {
        // Checks (in modifiers)
        if (tokenAddresses.length != amounts.length) {
            revert DeCup__TokenAddressesAndAmountsMusBeSameLength();
        }

        // Effects / Interctions
        uint256 tokenId = s_tokenCounter;

        if (msg.value > 0) {
            emit DepositeNativeCurrency(msg.sender, msg.value);
            s_collateralDeposited[tokenId][address(0)] += msg.value;
            s_tokenIdToAssets[tokenId].push(address(0));
        }

        _mintAndIncreaseCounter(msg.sender, tokenId);

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            if (amounts[i] == 0) {
                revert DeCup__AmountMustBeGreaterThanZero();
            }

            emit DepositeERC20Token(msg.sender, tokenAddresses[i], amounts[i]);
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
     * @notice Burns the NFT and withdraws all collateral assets to the caller
     * @param tokenId The ID of the NFT to burn and withdraw collateral from
     */
    function burn(uint256 tokenId) public override nonReentrant {
        address[] memory assets = s_tokenIdToAssets[tokenId];
        if (assets.length == 0) {
            revert DeCup__TokenDoesNotExist();
        }

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == address(0)) {
                _withdrawNativeCurrency(s_collateralDeposited[tokenId][assets[i]]);
            } else {
                _withdrawSingleToken(assets[i], s_collateralDeposited[tokenId][assets[i]]);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                           PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints a new token to the specified address and increments the token counter
     * @param to The address to mint the token to
     * @param tokenId The ID of the token to mint
     */
    function _mintAndIncreaseCounter(address to, uint256 tokenId) private {
        _safeMint(to, tokenId);
        s_tokenCounter++;
    }

    /**
     * @notice Function to withdraw native currency
     * @param amount - withdraw amount
     */
    function _withdrawNativeCurrency(uint256 amount) private {
        if (address(this).balance < amount) {
            revert DeCup__InsufficientBalance();
        }

        emit WithdrawNativeCurrency(msg.sender, amount);

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) {
            revert DeCup__TransferFailed();
        }
    }

    /**
     * @notice Function to withdraw a single ERC20 token
     * @param tokenAddress  - ERC20 contract address
     * @param amount - Amount of tokens to withdraw
     */
    function _withdrawSingleToken(address tokenAddress, uint256 amount) private moreThanZero(amount) {
        emit WithdrawERC20Token(msg.sender, tokenAddress, amount);

        if (!IERC20Metadata(tokenAddress).transfer(msg.sender, amount)) {
            revert DeCup__TransferFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                INTERNAL / PRIVATE VIEW / PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the base URI for token metadata in base64 JSON format
     */
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    /*//////////////////////////////////////////////////////////////
                EXTERNAL / PUBLIC VIEW / PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the USD value of a given token amount using Chainlink price feeds
     * @param tokenAddress The address of the ERC20 token to get the value for. Use address(0) for native currency
     * @param amount The amount of tokens to calculate the USD value for
     * @return The USD value of the given token amount with additional precision
     */
    function getUsdValue(address tokenAddress, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed;

        if (tokenAddress == address(0)) {
            priceFeed = AggregatorV3Interface(s_defaultPriceFeed);
        } else {
            priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[tokenAddress]);
        }

        (, int256 price,,,) = priceFeed.latestRoundData();

        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    /**
     * @notice Returns the metadata URI for a given token ID in base64 JSON format
     * @param _tokenId The ID of the token to get metadata for
     * @return A base64 encoded JSON string containing the token's metadata including name, description, attributes and image
     */
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        string memory imageURI = s_svgImageUri;
        address[] memory assets = s_tokenIdToAssets[_tokenId];

        bytes memory attributes;

        for (uint256 i = 0; i < assets.length; i++) {
            string memory symbol;
            uint256 amount = getUsdValue(assets[i], s_collateralDeposited[_tokenId][assets[i]]);

            if (assets[i] == address(0)) {
                // Native currency (ETH, MATIC, etc.)
                symbol = "ETH"; // You might want to make this configurable based on chain
            } else {
                // ERC20 token
                symbol = IERC20Metadata(assets[i]).symbol();
            }

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
        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name(),
                            '","description":"Decentralized Cup of assets", "attributes": [',
                            '{"trait_type":"TCL","value":"0 USD"}',
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
