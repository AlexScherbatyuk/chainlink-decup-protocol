// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IDeCup {
    // Standard ERC721 Events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    // Ownable Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Custom Events
    event DepositNativeCurrency(address indexed from, uint256 amount);
    event DepositERC20Token(address indexed from, address indexed token, uint256 amount);
    event WithdrawNativeCurrency(address indexed to, uint256 amount);
    event WithdrawERC20Token(address indexed to, address indexed token, uint256 amount);
    event TokenListedForSale(uint256 indexed tokenId);
    event TokenRemovedFromSale(uint256 indexed tokenId);

    // Deposit Functions
    function addTokenCollateralToExistingCup(address tokenAddress, uint256 amount, uint256 tokenId) external;
    function addNativeCollateralToExistingCup(uint256 tokenId) external payable;
    function depositSingleAssetAndMint(address tokenAddress, uint256 amount) external payable;
    function depositMultipleAssetsAndMint(address[] memory tokenAddresses, uint256[] memory amounts) external payable;

    // Sale Functions
    function listForSale(uint256 tokenId) external;
    function removeFromSale(uint256 tokenId) external;
    function transferAndBurn(uint256 tokenId, address to) external returns (bool);
    function transfer(uint256 tokenId, address to) external returns (bool);
    function burn(uint256 tokenId) external;

    // View Functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function getTokenCounter() external view returns (uint256);
    function getIsListedForSale(uint256 tokenId) external view returns (bool);
    function getERC20UsdValue(address tokenAddress, uint256 amount) external view returns (uint256);
    function getCollateralBalance(uint256 tokenId, address tokenAddress) external view returns (uint256);
    function getTokenAssetsList(uint256 tokenId) external view returns (address[] memory);
    function getAssetsInfo(uint256 tokenId) external view returns (string[] memory);
    function getTokenPriceInUsd(uint256 tokenId) external view returns (uint256);
    function tokenURI(uint256 _tokenId) external view returns (string memory);
    function ownerOf(uint256 tokenId) external view returns (address);

    // Standard ERC721 Functions
    function balanceOf(address owner) external view returns (uint256);
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    // Owner Functions
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}
