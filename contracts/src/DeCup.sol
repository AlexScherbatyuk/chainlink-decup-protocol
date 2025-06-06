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

/**
 * @title DeCup
 * @author Alexander Scherbatyuk
 * @notice Collaterised NFT (Cup of Assets) to be soled cross-chain as single NFT. Contract receive native currency and
 * a pre defiend number of ERC20 tokens as colleterral.
 * @dev This contract utilizes:
 * - Chainlink Price Feeds to calculate NFT price based on assets market prices,
 * - Chainlink CCIP to papulate transfer and burn functionalities cros-chain.
 */
contract DeCup is ERC721, ReentrancyGuard {
    // Errors
    error DeCup__AmountMustBeGreaterThanZero();
    error DeCup__TransferFailed();
    error DeCup__InsufficientBalance();
    error DeCup__NotAllowedToken();
    error DeCup__TokenAddressesAndPriceFeedAddressesMusBeSameLength();
    error DeCup__ApprovalFailed();

    // Structure to track deposited assets
    struct Asset {
        address token; // Address of the token (address(0) for native currency)
        string symbol; // Token Symbol (ETH, USDC, etc)
        uint256 amount; // Amount of tokens/native currency deposited
        uint256 timestamp; // When the asset was deposited
    }

    // State variables
    uint256 private s_tokenCounter;
    string private s_svgImageUri;

    mapping(uint256 tokenId => Asset[] assets) private s_tokenIdToAssets;
    mapping(address token => address priceFeed) private s_tokenToPriceFeed;
    mapping(uint256 tokenId => mapping(address token => uint256 amount)) private s_collateralDeposited;
    /// may be use mapping instead pf struct ???

    // Events
    event NativeReceived(address indexed from, uint256 amount);
    event ERC20Received(address indexed from, address indexed token, uint256 amount);
    event NativeWithdrawn(address indexed to, uint256 amount);
    event ERC20Withdrawn(address indexed to, address indexed token, uint256 amount);

    // Modifiers
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DeCup__AmountMustBeGreaterThanZero();
        }
        _;
    }

    modifier isAllowedToken(address tokenAddress) {
        if (s_tokenToPriceFeed[tokenAddress] == address(0)) {
            revert DeCup__NotAllowedToken();
        }
        _;
    }

    // Functions
    constructor(string memory _baseSvgImageUri, address[] memory tokenAddresses, address[] memory priceFeedAddresses)
        ERC721("DeCup", "DCT")
    {
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
     * Receive native currency (ETH)
     */
    receive() external payable moreThanZero(msg.value) nonReentrant {
        // Effect
        Asset[] memory assets = new Asset[](1);
        assets[0] = Asset({
            token: address(0), // address(0) represents native currency
            symbol: "ETH",
            amount: msg.value,
            timestamp: block.timestamp
        });

        emit NativeReceived(msg.sender, msg.value);

        // Interact
        _mintNft(assets);
    }

    /**
     * Function to receive ERC20 tokens
     * @param tokenAddress  - ERC20 contract address
     * @param amount - deposit amount
     */
    function depositeERC20(address tokenAddress, uint256 amount)
        external
        payable
        moreThanZero(amount)
        isAllowedToken(tokenAddress)
        nonReentrant
    {
        // Check (in modifiers)
        // Effect
        emit ERC20Received(msg.sender, tokenAddress, amount);

        //  Asset[] memory assets = new Asset[](1);
        //  assets[0] = Asset({
        //     token: tokenAddress, // address(0) represents native currency
        //     amount: msg.value,
        //     timestamp: block.timestamp
        // });


        s_collateralDeposited[s_tokenCounter][tokenAddress] = amount;
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenCounter++;
    }

        // Interact
        (bool success) = IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert DeCup__TransferFailed();
        }
    }

    /* Function to receive ERC20 tokens
     * @param tokenAddresses  - ERC20 contract address
     * @param amountss - deposit amount
     */
    function depositeMultipleAssets(address[] tokenAddresses, uint256[] amounts) external payable {
        // Check (in modifiers)
        if (msg.value > 0) {
            emit NativeReceived(msg.sender, amount);
        }
        // Effect
        emit ERC20Received(msg.sender, tokenAddress, amount);

        Asset[] memory assets = new Asset[](1);
        assets[0] = Asset({
            token: address(0), // address(0) represents native currency
            symbol: "ETH",
            amount: msg.value,
            timestamp: block.timestamp
        });

        // Interact
        (bool success) = IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert DeCup__TransferFailed();
        }

        // Interact
        //_mintNft(assets);
    }

    /**
     * Function to withdraw native currency
     * @param amount - withdraw amount
     */
    function withdrawNative(uint256 amount) external {
        require(amount > 0, DeCup__AmountMustBeGreaterThanZero());
        require(address(this).balance >= amount, DeCup__InsufficientBalance());

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, DeCup__TransferFailed());

        emit NativeWithdrawn(msg.sender, amount);
    }

    /**
     * Function to withdraw ERC20 tokens
     * @param token  - ERC20 contract address
     * @param amount - withdraw amount
     */
    function withdrawERC20(address token, uint256 amount) external {
        //require(amount > 0, DeCup__AmountMustBeGreaterThanZero());
        if (amount <= 0) {
            revert DeCup__AmountMustBeGreaterThanZero();
        }

        require(IERC20(token).balanceOf(address(this)) >= amount, DeCup__InsufficientBalance());
        require(IERC20(token).transfer(msg.sender, amount), DeCup__TransferFailed());

        emit ERC20Withdrawn(msg.sender, token, amount);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        string memory imageURI = s_svgImageUri;
        Asset[] memory assets = s_tokenIdToAssets[_tokenId];
        bytes memory traits = "";

        for (uint256 index = 0; index < assets.length; index++) {
            traits = abi.encodePacked(
                traits, ',{"trait_type":"', assets[index].symbol, '","value":"', assets[index].amount, '"}'
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
                            '","description":"Decentralised Cup of Assets", "attributes": [',
                            traits,
                            '],"image":"',
                            imageURI,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    function _mintNft( memory _assets) internal {
                s_collateralDeposited[[s_tokenCounter] = _assets;
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenCounter++;
    }

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
