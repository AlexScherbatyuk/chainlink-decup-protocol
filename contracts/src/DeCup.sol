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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

/**
 * @title DeCup
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

    // Structure to track deposited assets
    // struct Asset {
    //     address token; // Address of the token (address(0) for native currency)
    //     string symbol; // Token Symbol (ETH, USDC, etc)
    //     uint256 amount; // Amount of tokens/native currency deposited
    //     uint256 timestamp; // When the asset was deposited
    // }

    // State variables
    uint256 private s_tokenCounter;
    string private s_svgImageUri;

    mapping(uint256 tokenId => address[] assets) private s_tokenIdToAssets;
    mapping(address tokenAddress => address priceFeed) private s_tokenToPriceFeed;
    mapping(uint256 tokenId => mapping(address token => uint256 amount)) private s_collateralDeposited;
    /// may be use mapping instead pf struct ???

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
     * @param tokenAddresses Array of ERC20 token addresses that can be used as collateral
     * @param priceFeedAddresses Array of Chainlink price feed addresses corresponding to each token
     */
    constructor(string memory _baseSvgImageUri, address[] memory tokenAddresses, address[] memory priceFeedAddresses)
        ERC721("DeCup", "DCT")
    {
        if (tokenAddresses.length == 0) {
            revert DeCup__AllowedTokenAddressesMustNotBeEmpty();
        }

        if (priceFeedAddresses.length == 0) {
            revert DeCup__PriceFeedAddressesMustNotBeEmpty();
        }

        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DeCup__TokenAddressesAndPriceFeedAddressesMusBeSameLength();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_tokenToPriceFeed[tokenAddresses[i]] = priceFeedAddresses[i];
        }

        s_tokenCounter = 0;
        s_svgImageUri = _baseSvgImageUri;
    }

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

    // External functions

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
        (bool success) = IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
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

            (bool success) = IERC20(tokenAddresses[i]).transferFrom(msg.sender, address(this), amounts[i]);
            if (!success) {
                revert DeCup__TransferFailed();
            }
        }
    }

    // Public functionss
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

    // Private functionss

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

        if (!IERC20(tokenAddress).transfer(msg.sender, amount)) {
            revert DeCup__TransferFailed();
        }
    }

    /**
     * @notice Returns the base URI for token metadata in base64 JSON format
     */
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }
}

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
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
