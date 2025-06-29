# DeCup Smart Contracts

A decentralized NFT marketplace for collateralized "Cups of Assets" with cross-chain functionality powered by Chainlink services.

## 🔗 Chainlink Integration

This project extensively leverages Chainlink's decentralized oracle network and cross-chain infrastructure:

### Chainlink CCIP (Cross-Chain Interoperability Protocol)
The project uses **Chainlink CCIP** for cross-chain operations:

**In DeCupManager.sol:**
- **Lines 7-10**: Imports of CCIP interfaces and libraries:
  - `IRouterClient` - For sending cross-chain messages
  - `Client` - For message structure definitions
  - `LinkTokenInterface` - For LINK token payments
  - `CCIPReceiver` - For receiving cross-chain messages
- **Functionality**:
  - Cross-chain NFT marketplace operations
  - Cross-chain message passing for sale creation, cancellation, and execution
  - Cross-chain token transfers with burn capability
  - LINK or native token fee payment options
  - Multi-chain receiver management

**In IDeCupManager.sol:**
- **Line 3**: Import of CCIP Client library for interface definitions

### Chainlink Price Feeds
The project uses **Chainlink Price Feeds** (AggregatorV3Interface) for real-time price data:

**In DeCup.sol:**
- **Line 9**: Import of `AggregatorV3Interface` from Chainlink contracts
- **Line 18-19**: Contract documentation explicitly mentions Chainlink Price Feeds usage
- **Line 154**: Constructor parameter for Chainlink price feed addresses
- **Lines 573, 596, 599, 668**: Multiple functions use Chainlink price feeds to calculate USD values
- **Functionality**: 
  - Real-time token price retrieval for collateral valuation
  - USD-denominated NFT pricing based on underlying asset values
  - Price feed validation and fallback mechanisms

**In DeCupManager.sol:**
- **Line 6**: Import of `AggregatorV3Interface`
- **Line 180**: Constructor parameter for Chainlink price feed address
- **Line 775**: Function to get latest price data from Chainlink feeds
- **Functionality**:
  - ETH/USD price conversion for marketplace operations
  - Fee calculations in USD converted to ETH
  - Cross-chain price synchronization

### Chainlink Infrastructure Files
The project includes comprehensive Chainlink testing and deployment infrastructure:
- **HelperConfigDeCup.s.sol & HelperConfigDeCupManager.s.sol**: Use MockV3Aggregator for local testing
- **CCIPInteractions.t.sol**: Integration tests using CCIPLocalSimulatorFork
- **Multiple library files**: Chainlink-brownie-contracts for various Chainlink services

---

## 📋 Contract Overview

### DeCup.sol
The core NFT contract that represents collateralized "Cups of Assets".

**Key Features:**
- **Collateralized NFTs**: Each NFT represents a basket of ERC20 tokens and/or native currency
- **Dynamic Pricing**: NFT values calculated in real-time using Chainlink price feeds
- **Flexible Deposits**: Support for single or multiple asset deposits
- **Burn-to-Withdraw**: Token holders can burn NFTs to withdraw underlying collateral
- **SVG Metadata**: Dynamic SVG generation for NFT visualization

**Core Functions:**
- `receive()`: Mint NFT with native currency collateral
- `depositSingleAssetAndMint()`: Mint NFT with single ERC20 token
- `depositMultipleAssetsAndMint()`: Mint NFT with multiple assets
- `addTokenCollateralToExistingCup()`: Add ERC20 tokens to existing NFT
- `addNativeCollateralToExistingCup()`: Add native currency to existing NFT
- `burn()`: Burn NFT and withdraw all collateral
- `transfer()` & `transferAndBurn()`: Manager-controlled transfers

**Access Control:**
- Token owners can add collateral and burn (when not listed for sale)
- Contract manager can list/unlist tokens and execute transfers
- Reentrancy protection on all state-changing functions

### DeCupManager.sol
The marketplace and cross-chain management contract.

**Key Features:**
- **Cross-Chain Marketplace**: Create, cancel, and execute sales across different chains
- **USD-Denominated Pricing**: All prices set and calculated in USD using Chainlink feeds
- **CCIP Integration**: Full cross-chain interoperability for NFT operations
- **Collateral Management**: User collateral tracking for fees and payments
- **Multi-Chain Support**: Configurable support for multiple destination chains

**Core Functions:**
- `createCrossSale()`: Create sale order on destination chain
- `cancelCrossSale()`: Cancel existing cross-chain sale
- `buyCrossSale()`: Purchase NFT from another chain
- `ccipReceive()`: Handle incoming CCIP messages
- `enableChain()` / `disableChain()`: Configure supported chains

**Cross-Chain Operations:**
- **CreateSale**: Broadcast NFT sale to destination chain
- **CancelSale**: Remove sale listing across chains  
- **Buy**: Execute purchase and transfer NFT cross-chain
- **Message Structure**: Comprehensive data passing for all operations

### Interface Contracts

**IDeCup.sol** (61 lines)
- Complete interface for DeCup NFT contract
- Getter functions for token metadata and collateral information
- Event definitions for all major operations

**IDeCupManager.sol** (139 lines)
- Complete interface for DeCupManager contract
- CCIP message structures and enums
- Cross-chain configuration functions

---

## 🛠 Technical Architecture

### Price Feed Integration
- **Real-time Pricing**: All asset valuations use Chainlink's decentralized price feeds
- **Multi-token Support**: Each supported ERC20 token has a corresponding price feed
- **Precision Handling**: Standardized decimal handling across different tokens and feeds
- **Fallback Protection**: Price feed validation and error handling

### Cross-Chain Architecture
- **Message Routing**: CCIP router configuration for each supported chain
- **Fee Management**: Flexible fee payment in LINK or native tokens
- **State Synchronization**: Cross-chain state management for marketplace operations
- **Chain Configuration**: Dynamic addition/removal of supported chains

### Security Features
- **Reentrancy Protection**: OpenZeppelin's ReentrancyGuard on all critical functions
- **Access Control**: Multi-level permission system (owner, manager, token holder)
- **Input Validation**: Comprehensive checks on all parameters
- **CEI Pattern**: Consistent Checks-Effects-Interactions implementation

---

## 🚀 Deployment Configuration

### Required Dependencies
- **Chainlink Contracts**: `@chainlink/contracts` for price feeds and CCIP
- **OpenZeppelin**: `@openzeppelin/contracts` for standard implementations
- **Foundry**: Build and testing framework

### Constructor Parameters

**DeCup.sol:**
```solidity
constructor(
    string memory _baseSvgImageUri,      // Base URI for NFT images
    address[] memory _tokenAddresses,    // Supported ERC20 tokens
    address[] memory _priceFeedAddresses, // Corresponding Chainlink price feeds
    address _defaultPriceFeed,           // ETH/USD price feed
    string memory _defaultSymbol         // Default currency symbol
)
```

**DeCupManager.sol:**
```solidity
constructor(
    address decupAddress,                    // DeCup NFT contract address
    address priceFeedAddress,               // ETH/USD Chainlink price feed
    uint64[] memory destinationChainIds,    // Supported chain IDs
    uint64[] memory destinationChainSelectors, // CCIP chain selectors
    address[] memory linkTokens,            // LINK token addresses per chain
    address[] memory routerAddress          // CCIP router addresses per chain
)
```

---

## 📊 Usage Examples

### Minting a DeCup NFT
```solidity
// Mint with native currency only
payable(deCupAddress).call{value: 1 ether}("");

// Mint with single ERC20 token
deCup.depositSingleAssetAndMint(usdcAddress, 1000e6);

// Mint with multiple assets
address[] memory tokens = [usdcAddress, daiAddress];
uint256[] memory amounts = [1000e6, 1000e18];
deCup.depositMultipleAssetsAndMint{value: 0.5 ether}(tokens, amounts);
```

### Cross-Chain Marketplace Operations
```solidity
// Create cross-chain sale (from Sepolia to Avalanche Fuji)
manager.createCrossSale{value: ccipFee}(
    tokenId, 
    beneficiaryAddress, 
    43113, // Avalanche Fuji chain ID
    priceInUsd
);

// Buy from another chain (from Avalanche Fuji)
manager.buyCrossSale{value: price + ccipFee}(
    saleId,
    buyerAddress,
    11155111, // Sepolia chain ID
    false // Don't burn after transfer
);
```

---

## 🧪 Testing Framework

The project includes comprehensive testing infrastructure:
- **Unit Tests**: Individual contract function testing
- **Integration Tests**: Cross-chain operation testing with CCIP simulators
- **Mock Contracts**: Chainlink MockV3Aggregator for local development
- **Fork Testing**: Real network testing capabilities

---

## 🛠 Available Make Commands

The project includes a comprehensive Makefile with commands for development, deployment, and interaction:

### Installation
```bash
make install                    # Install all required dependencies (OpenZeppelin, Foundry DevOps, Chainlink contracts)
```

### Local Development (Anvil)
```bash
make deploy-anvil              # Deploy DeCupManager to local Anvil node
make deposit-eth-anvil         # Deposit ETH and mint NFT on Anvil
make deposit-multiple-anvil    # Deposit multiple assets and mint NFT on Anvil
```

### Sepolia Testnet Deployment
```bash
make deploy-sepolia           # Deploy DeCupManager to Sepolia with verification
make deposit-eth-sepolia      # Deposit ETH and mint NFT on Sepolia
```

### Sepolia Testnet Interactions
```bash
make create-sale-sepolia TOKEN_ID=<id>                    # Create sale for specific token ID
make add-single-asset-cup-sepolia TOKEN_ID=<id>          # Add single asset to existing cup
make get-nft-collateral-sepolia TOKEN_ID=<id> TOKEN_ADDRESS=<addr>  # Get NFT collateral info
make get-nft-tcl-sepolia                                  # Get NFT Total Collateral Value (TCL)
make burn-eth-sepolia                                     # Burn NFT and withdraw collateral
```

### Environment Variables Required
Create a `.env` file with:
```bash
SEPOLIA_RPC_URL=your_sepolia_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key
# Account keys should be configured in Foundry's keystore
```

### Usage Examples
```bash
# Deploy to Sepolia
make deploy-sepolia

# Mint NFT with ETH
make deposit-eth-sepolia

# Create a sale for token ID 1
make create-sale-sepolia TOKEN_ID=1

# Add collateral to token ID 1
make add-single-asset-cup-sepolia TOKEN_ID=1

# Check collateral for token ID 1 and USDC
make get-nft-collateral-sepolia TOKEN_ID=1 TOKEN_ADDRESS=0xA0b86a33E6417c7e4a4e4B04e9a4c0D33a0a0B0c
```

---

## 📄 License

MIT License - See LICENSE file for details.
