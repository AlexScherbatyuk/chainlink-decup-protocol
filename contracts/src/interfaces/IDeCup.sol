// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IDeCup {
    // Events
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
    function getTokenCounter() external view returns (uint256);
    function getIsListedForSale(uint256 tokenId) external view returns (bool);
    function getUsdcUSDValue(address tokenAddress, uint256 amount) external view returns (uint256);
    function getCollateralDeposited(uint256 tokenId, address tokenAddress) external view returns (uint256);
    function getTokenAssetsList(uint256 tokenId) external view returns (address[] memory);
    function getTokenIdTCL(uint256 tokenId) external view returns (uint256);
    function tokenURI(uint256 _tokenId) external view returns (string memory);
    function ownerOf(uint256 tokenId) external view returns (address);

    // Owner Functions
    function transferOwnership(address newOwner) external;
}
