# Decup Frontend

## Project Overview

This is the frontend user interface for the Decup project - a modern, intuitive web application that provides a simple interface for interacting with Solidity smart contracts. Built with Next.js and React, the UI offers users an accessible way to engage with blockchain functionality without requiring deep technical knowledge of smart contract interactions.

## User Interface

The frontend features a clean, responsive design built with:

- **Next.js 15** - React framework for server-side rendering and optimal performance
- **TypeScript** - Type-safe development for better code quality and developer experience
- **Tailwind CSS** - Utility-first CSS framework for rapid styling
- **Radix UI** - Accessible, unstyled UI components for building a professional interface
- **Wagmi & Viem** - Ethereum integration libraries for seamless blockchain interactions

## Key Features

- **Simple Smart Contract Interaction**: Users can easily interact with deployed smart contracts through an intuitive web interface
- **Wallet Integration**: Seamless connection with popular Web3 wallets
- **Responsive Design**: Works across desktop and mobile devices
- **Modern UI Components**: Professional interface with accessibility features built-in
- **Real-time Updates**: Dynamic updates when interacting with blockchain data

## Smart Contracts

This frontend interfaces with Solidity smart contracts that handle the core business logic. For detailed information about the smart contracts, their functionality, and technical specifications, please refer to the [Smart Contracts Documentation](../contracts/README.md).

### Smart Contract Functions Utilized

The frontend's `interactions.ts` file integrates with the following smart contract functions:

#### DeCup Contract Functions
- **`depositSingleAssetAndMint`** - Deposits ERC20 tokens and mints a new NFT
- **`addTokenCollateralToExistingCup`** - Adds ERC20 token collateral to an existing cup/NFT
- **`burn`** - Burns/destroys an NFT and releases collateral
- **`getTokenPriceInUsd`** - Retrieves the USD price of a token
- **`getCollateralBalance`** - Gets the collateral balance for a specific token address
- **`ownerOf`** - Returns the current owner of an NFT (standard ERC721 function)
- **`getTokenAssetsList`** - Gets the list of token addresses held in a cup
- **`getIsListedForSale`** - Checks if a token is currently listed for sale

#### DeCupManager Contract Functions
- **`withdrawFunds`** - Withdraws native currency funds from the manager
- **`createSale`** - Creates a sale listing for a DeCup NFT
- **`cancelSale`** - Cancels an existing sale listing
- **`buy`** - Purchases an NFT from a sale listing
- **`getSaleOrder`** - Retrieves details of a specific sale order
- **`getCcipCollateralInEth`** - Gets CCIP collateral value denominated in ETH
- **`getCcipCollateralInUsd`** - Gets CCIP collateral value denominated in USD  
- **`getPriceInETH`** - Converts a USD price to ETH equivalent

#### ERC20 Token Functions
- **`decimals`** - Gets the decimal places for an ERC20 token
- **`allowance`** - Checks the spending allowance for a token
- **`approve`** - Approves token spending for contract interactions

#### Events Monitored
The frontend also listens to and processes the following blockchain events:
- **Transfer** - NFT minting, burning, and ownership transfers
- **DepositNativeCurrency** - Native token deposits
- **DepositERC20Token** - ERC20 token deposits
- **CreateSale** - Sale listing creation
- **CancelSale** - Sale listing cancellation
- **Buy** - NFT purchase transactions

These functions enable comprehensive interaction with the DeCup ecosystem, including collateral management, NFT operations, marketplace functionality, and cross-chain features.

## Getting Started

To run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the application.

## Project Structure

The application is organized with clear separation of concerns:
- `app/` - Next.js app router pages and layouts
- `components/` - Reusable UI components
- `hooks/` - Custom React hooks for blockchain interactions
- `lib/` - Utility functions and configurations
- `store/` - State management with Zustand
- `context/` - React context providers
- `config/` - Application configuration files

This frontend serves as the bridge between users and the underlying smart contract infrastructure, making blockchain interactions accessible through a polished, user-friendly interface.
