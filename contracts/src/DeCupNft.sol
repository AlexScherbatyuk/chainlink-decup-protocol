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
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title Cup of Assets, collaterised NFTs
 * @author Alexander Scherbatyuk
 * @notice Collaterised NFT (Cup of Assets) to be soled cross-chain as single NFT.
 * @dev fllows ...
 */
contract DeCupNft is ERC721 {
    // Errors
    error DeCupNft__AmountMustBeGreaterThanZero();
    error DeCupNft__TransferFailed();
    error DeCupNft__InsufficientBalance();

    // Structure to track deposited assets
    struct Asset {
        address token;      // Address of the token (address(0) for native currency)
        string  symbol;       // Token Symbol (ETH, USDC, etc)
        uint256 amount;     // Amount of tokens/native currency deposited
        uint256 timestamp; // When the asset was deposited
    } 


    // State variables
    uint256 private s_tokenCounter;
    string private s_svgImageUri;

    mapping (uint256 => Asset[]) private s_tokenIdToAssets;
    

    // Events
    event NativeReceived(address indexed from, uint256 amount);
    event ERC20Received(address indexed from, address indexed token, uint256 amount);
    event NativeWithdrawn(address indexed to, uint256 amount);
    event ERC20Withdrawn(address indexed to, address indexed token, uint256 amount);

    // Functions
    constructor(string memory _baseSvgImageUri) ERC721("DeCup", "DCT") {
        s_tokenCounter = 0;
        s_svgImageUri = _baseSvgImageUri;
    }

    /**
     * Receive native currency (ETH)
     */
    receive() external payable {
        // Check
        if (msg.value <= 0) {
            revert DeCupNft__AmountMustBeGreaterThanZero();
        }
        // Effect
        emit NativeReceived(msg.sender, msg.value);

        //Interact
    }

    /**
     * Function to receive ERC20 tokens
     * @param token  - ERC20 contract address
     * @param amount - deposit amount
     */
    function receiveERC20(address token, uint256 amount) external {
        // Check
        if (amount <= 0) {
            revert DeCupNft__AmountMustBeGreaterThanZero();
        }
        // Effect
        emit ERC20Received(msg.sender, token, amount);

        // Interact
        (bool success) = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert DeCupNft__TransferFailed();
        }
        
    }

    /**
     * Function to withdraw native currency
     * @param amount - withdraw amount
     */
    function withdrawNative(uint256 amount) external {
        require(amount > 0, DeCupNft__AmountMustBeGreaterThanZero());
        require(address(this).balance >= amount, DeCupNft__InsufficientBalance());

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, DeCupNft__TransferFailed());
        
        emit NativeWithdrawn(msg.sender, amount);
    }

    /**
     * Function to withdraw ERC20 tokens
     * @param token  - ERC20 contract address
     * @param amount - withdraw amount
     */

    function withdrawERC20(address token, uint256 amount) external {
        //require(amount > 0, DeCupNft__AmountMustBeGreaterThanZero());
       if (amount <= 0) {
            revert DeCupNft__AmountMustBeGreaterThanZero();
        }

        require(IERC20(token).balanceOf(address(this)) >= amount, DeCupNft__InsufficientBalance());   
        require(IERC20(token).transfer(msg.sender, amount), DeCupNft__TransferFailed());
        
        emit ERC20Withdrawn(msg.sender, token, amount);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        string memory imageURI = s_svgImageUri;
        Asset[] memory assets = s_tokenIdToAssets[_tokenId];
        bytes memory traits = "";

        for (uint256 index = 0; index < assets.length; index++) {
            traits = abi.encodePacked(traits, ',{"trait_type":"',assets[index].symbol,'","value":"',assets[index].amount,'"}');
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

    function _mintNft(Asset[] memory _assets) internal {
        s_tokenIdToAssets[s_tokenCounter] = _assets;
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
