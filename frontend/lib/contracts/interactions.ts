import { sendTransaction, readContract, writeContract, waitForTransactionReceipt, getPublicClient } from '@wagmi/core'
import { config } from '@/config'
import { erc20Abi, parseEventLogs } from 'viem'
import { DeCupManagerABI, DeCupABI } from '@/lib/contracts/abis'

/**
 * @notice Deposits a native token into the DeCup contract and mints an NFT
 * @param amount The amount of tokens to deposit
 * @param contractAddress The address of the DeCup contract
 * @param walletAddress The address of the wallet to deposit the tokens from
 * @returns { success: boolean, tokenId?: bigint }
 */
const depositNative = async (amount: bigint, contractAddress: string, walletAddress?: string): Promise<{ success: boolean; tokenId?: bigint }> => {

    let success = false
    let tokenId: bigint | undefined

    try {
        const tx = await sendTransaction(config, {
            to: contractAddress as `0x${string}`,
            value: amount,
        })

        if (tx) {
            // Wait for transaction to be mined
            const receipt = await waitForTransactionReceipt(config, {
                hash: tx,
            })

            // Parse logs for Transfer event
            const logs = parseEventLogs({
                abi: DeCupABI.abi,
                logs: receipt.logs,
            });

            // Parse events to find the NFT Transfer event (mint)
            const transferEvent = logs.find(
                (log: any) =>
                    log.eventName === 'Transfer' &&
                    log.args?.from === '0x0000000000000000000000000000000000000000' &&
                    log.args?.to?.toLowerCase() === walletAddress?.toLowerCase()
            );

            if ((transferEvent as any)?.args?.tokenId !== undefined) {
                const tokenId = (transferEvent as any).args.tokenId as bigint;
                console.log('Minted tokenId:', tokenId.toString());
                return {
                    success: true,
                    tokenId,
                    // transactionHash: txHash,
                };
            } else {
                console.warn('Transfer event found, but tokenId not parsed.');
                return {
                    success: true, // Transaction succeeded, but no tokenId
                    //transactionHash: txHash,
                };
            }
        }
    } catch (error) {
        console.error("Error depositing native token:", error)
        throw error
    }

    return { success, tokenId }
}

/**
 * @notice Adds a native token collateral to an existing cup
 * @param amount The amount of tokens to deposit
 * @param contractAddress The address of the DeCup contract
 * @param walletAddress The address of the wallet to deposit the tokens from
 * @param tokenId The ID of the token to add the collateral to
 * @returns { success: boolean, tokenId?: bigint }
 */
const addNativeCollateralToExistingCup = async (amount: bigint, contractAddress: string, walletAddress?: string, tokenId?: bigint): Promise<{ success: boolean; tokenId?: bigint }> => {

    let success = false
    try {
        const tx = await sendTransaction(config, {
            to: contractAddress as `0x${string}`,
            value: amount,
        })

        if (tx) {
            // Wait for transaction to be mined
            const receipt = await waitForTransactionReceipt(config, {
                hash: tx,
            })

            // Parse logs for Transfer event
            const logs = parseEventLogs({
                abi: DeCupABI.abi,
                logs: receipt.logs,
            });

            // Parse events to find the NFT Transfer event (mint)
            const transferEvent = logs.find(
                (log: any) =>
                    log.eventName === 'DepositNativeCurrency' &&
                    log.args?.from?.toLowerCase() === walletAddress?.toLowerCase() &&
                    log.args?.to?.toLowerCase() === contractAddress?.toLowerCase()
            );

            if ((transferEvent as any)?.args?.tokenId !== undefined) {
                const tokenId = (transferEvent as any).args.tokenId as bigint;
                console.log('Add collateral to existing cup tokenId:', tokenId.toString());
                return {
                    success: true,
                    tokenId,
                    // transactionHash: txHash,
                };
            } else {
                console.warn('Transfer event found, but tokenId not parsed.');
                return {
                    success: true, // Transaction succeeded, but no tokenId
                    //transactionHash: txHash,
                };
            }
        }
    } catch (error) {
        console.error("Error depositing native token:", error)
        throw error
    }

    return { success, tokenId }
}

/**
 * @notice Deposits an ERC20 token into the DeCup contract and mints an NFT
 * @param amount The amount of tokens to deposit
 * @param tokenAddress The address of the ERC20 token to deposit
 * @param contractAddress The address of the DeCup contract
 * @param walletAddress The address of the wallet to deposit the tokens from
 * @returns { success: boolean, tokenId?: bigint }
 */
const depositERC20 = async (amount: bigint, tokenAddress: string, contractAddress: string, walletAddress?: string): Promise<{ success: boolean; tokenId?: bigint }> => {

    let success = false
    let tokenId: bigint | undefined

    console.log("amount", amount)
    console.log("tokenAddress", tokenAddress)
    console.log("spenderAddress", contractAddress)
    console.log("walletAddress", walletAddress)

    try {

        const tokenDecimals = await readContract(config, {
            address: tokenAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: 'decimals',
        })
        console.log("tokenDecimals", tokenDecimals)

        const allowance = await readContract(config, {
            address: tokenAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: 'allowance',
            args: [walletAddress as `0x${string}`, contractAddress as `0x${string}`],
        })

        console.log("allowance", allowance)
        //10 000 000 000 000 000
        //10 000 000 000 000 000 000 000
        // Convert amount to token's smallest unit (account for token decimals)
        const amountInTokenDecimals = (amount * BigInt(10 ** tokenDecimals)) / BigInt(1e18)

        if (allowance < amountInTokenDecimals) {
            await writeContract(config, {
                address: tokenAddress as `0x${string}`,
                abi: erc20Abi,
                functionName: 'approve',
                args: [contractAddress as `0x${string}`, amountInTokenDecimals],
            })
        }

        console.log("amountInTokenDecimals", amountInTokenDecimals)

        // This would typically be a contract call, not a direct transaction
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'depositSingleAssetAndMint', // Or whatever the deposit function is called
            args: [tokenAddress, amountInTokenDecimals],
        })

        if (tx) {
            const receipt = await waitForTransactionReceipt(config, {
                hash: tx,
            })

            // Parse logs for Transfer event
            const logs = parseEventLogs({
                abi: DeCupABI.abi,
                logs: receipt.logs,
            });

            // Parse events to find the NFT Transfer event (mint)
            const transferEvent = logs.find(
                (log: any) =>
                    log.eventName === 'Transfer' &&
                    log.args?.from === '0x0000000000000000000000000000000000000000' &&
                    log.args?.to?.toLowerCase() === walletAddress?.toLowerCase()
            );

            if ((transferEvent as any)?.args?.tokenId !== undefined) {
                const tokenId = (transferEvent as any).args.tokenId as bigint;
                console.log('Minted tokenId:', tokenId.toString());
                return {
                    success: true,
                    tokenId,
                    // transactionHash: txHash,
                };
            } else {
                console.warn('Transfer event found, but tokenId not parsed.');
                return {
                    success: true, // Transaction succeeded, but no tokenId
                    //transactionHash: txHash,
                };
            }
        }
    } catch (error) {
        console.error("Error depositing ERC20 token:", error)
        throw error
    }

    return { success, tokenId }
}

/**
 * @notice Adds a token collateral to an existing cup
 * @param amount The amount of tokens to deposit
 * @param tokenAddress The address of the ERC20 token to deposit
 * @param contractAddress The address of the DeCup contract
 * @param walletAddress The address of the wallet to deposit the tokens from
 * @returns { success: boolean, tokenId?: bigint }
 */
const addTokenCollateralToExistingCup = async (amount: bigint, tokenAddress: string, contractAddress: string, walletAddress?: string, tokenId?: bigint): Promise<{ success: boolean; tokenId?: bigint }> => {

    let success = false
    //let tokenId: bigint | undefined

    console.log("amount", amount)
    console.log("tokenAddress", tokenAddress)
    console.log("spenderAddress", contractAddress)
    console.log("walletAddress", walletAddress)

    try {

        const tokenDecimals = await readContract(config, {
            address: tokenAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: 'decimals',
        })
        console.log("tokenDecimals", tokenDecimals)

        const allowance = await readContract(config, {
            address: tokenAddress as `0x${string}`,
            abi: erc20Abi,
            functionName: 'allowance',
            args: [walletAddress as `0x${string}`, contractAddress as `0x${string}`],
        })

        console.log("allowance", allowance)
        //10 000 000 000 000 000
        //10 000 000 000 000 000 000 000
        // Convert amount to token's smallest unit (account for token decimals)
        const amountInTokenDecimals = (amount * BigInt(10 ** tokenDecimals)) / BigInt(1e18)

        if (allowance < amountInTokenDecimals) {
            await writeContract(config, {
                address: tokenAddress as `0x${string}`,
                abi: erc20Abi,
                functionName: 'approve',
                args: [contractAddress as `0x${string}`, amountInTokenDecimals],
            })
        }

        console.log("amountInTokenDecimals", amountInTokenDecimals)

        // This would typically be a contract call, not a direct transaction
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'addTokenCollateralToExistingCup', // Or whatever the deposit function is called
            args: [tokenAddress, amountInTokenDecimals, tokenId],
        })

        if (tx) {
            const receipt = await waitForTransactionReceipt(config, {
                hash: tx,
            })

            // Parse logs for Transfer event
            const logs = parseEventLogs({
                abi: DeCupABI.abi,
                logs: receipt.logs,
            });

            // Parse events to find the NFT Transfer event (mint)
            const transferEvent = logs.find(
                (log: any) =>
                    log.eventName === 'DepositERC20Token' &&
                    log.args?.from?.toLowerCase() === walletAddress?.toLowerCase() &&
                    log.args?.to?.toLowerCase() === contractAddress?.toLowerCase()
            );

            if ((transferEvent as any)?.args?.tokenId !== undefined) {
                const tokenId = (transferEvent as any).args.tokenId as bigint;
                console.log('Add ERC20 collateral to existing cup tokenId:', tokenId.toString());
                return {
                    success: true,
                    tokenId,
                    // transactionHash: txHash,
                };
            } else {
                console.warn('Transfer event found, but tokenId not parsed.');
                return {
                    success: true, // Transaction succeeded, but no tokenId
                    //transactionHash: txHash,
                };
            }
        }
    } catch (error) {
        console.error("Error depositing ERC20 token:", error)
        throw error
    }

    return { success, tokenId }
}


const withdrawNativeDeCupManager = async (amount: bigint, contractAddress: string): Promise<boolean> => {
    let success = false

    try {
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupManagerABI.abi,
            functionName: 'withdrawFunds',
            args: [],
        })

        if (tx) {
            success = true
        }
    } catch (error) {
        console.error("Error withdrawing native token:", error)
        throw error
    }

    return success
}

const burnDeCupNFT = async (tokenId: bigint, contractAddress: string): Promise<boolean> => {
    let success = false

    try {
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'burn',
            args: [tokenId],
        })

        if (tx) {
            success = true
        }
    } catch (error) {
        console.error("Error burning DeCup NFT:", error)
        throw error
    }

    return success
}

/**
 * @notice Creates a sale for a DeCup NFT
 * @param tokenId The ID of the token to sell
 * @param beneficialWallet The address of the wallet to receive the funds
 * @param contractAddress The address of the DeCupManager contract
 * @param sourceChainId The ID of the source chain
 * @param destinationChainId The ID of the destination chain
 * @returns { success: boolean, saleId?: bigint }
 */
const createSale = async (tokenId: bigint, beneficialWallet: string, contractAddress: string, sourceChainId: number, destinationChainId: number): Promise<{ success: boolean; saleId?: bigint }> => {

    let success = false
    let saleId: bigint | undefined

    try {
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupManagerABI.abi,
            functionName: 'createSale',
            args: [tokenId, beneficialWallet],
        })

        if (tx) {
            const receipt = await waitForTransactionReceipt(config, {
                hash: tx,
            })

            // Parse logs for Transfer event
            const logs = parseEventLogs({
                abi: DeCupManagerABI.abi,
                logs: receipt.logs,
            });

            // Parse events to find the NFT Transfer event (mint)
            const transferEvent = logs.find(
                (log: any) =>
                    log.eventName === 'CreateSale' &&
                    log.args?.tokenId === tokenId &&
                    log.args?.sourceChainId == sourceChainId &&
                    log.args?.destinationChainId == destinationChainId &&
                    log.args?.sellerAddress === '0x0000000000000000000000000000000000000000' &&
                    log.args?.beneficialWallet?.toLowerCase() === beneficialWallet?.toLowerCase()
            );

            if ((transferEvent as any)?.args?.saleId !== undefined) {
                const saleId = (transferEvent as any).args.saleId as bigint;
                console.log('Minted tokenId:', saleId.toString());
                return {
                    success: true,
                    saleId,
                    // transactionHash: txHash,
                };
            } else {
                console.warn('Transfer event found, but tokenId not parsed.');
                return {
                    success: true, // Transaction succeeded, but no tokenId
                    //transactionHash: txHash,
                };
            }
        }
    } catch (error) {
        console.error("Error create DeCup NFT Manager sale for a token:", error)
        throw error
    }

    return { success, saleId }
}

/**
 * @notice Cancels a sale for a DeCup NFT
 * @param saleId The ID of the sale to cancel
 * @param contractAddress The address of the DeCupManager contract
 * @returns { success: boolean, saleId?: bigint }
 */
const cancelSale = async (saleId: bigint, contractAddress: string): Promise<{ success: boolean; saleId?: bigint }> => {

    let success = false

    try {
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupManagerABI.abi,
            functionName: 'cancelSale',
            args: [saleId],
        })

        if (tx) {
            const receipt = await waitForTransactionReceipt(config, {
                hash: tx,
            })

            // Parse logs for Transfer event
            const logs = parseEventLogs({
                abi: DeCupManagerABI.abi,
                logs: receipt.logs,
            });

            // Parse events to find the NFT Transfer event (mint)
            const transferEvent = logs.find(
                (log: any) =>
                    log.eventName === 'CancelSale' &&
                    log.args?.saleId === saleId
            );

            if ((transferEvent as any)?.args?.saleId !== undefined) {
                const saleId = (transferEvent as any).args.saleId as bigint;
                console.log('Canceled saleId:', saleId.toString());
                return {
                    success: true,
                    saleId,
                    // transactionHash: txHash,
                };
            } else {
                console.warn('Transfer event found, but tokenId not parsed.');
                return {
                    success: true, // Transaction succeeded, but no tokenId
                    //transactionHash: txHash,
                };
            }
        }
    } catch (error) {
        console.error("Error removing DeCup NFT sale:", error)
        throw error
    }

    return { success, saleId }
}

/**
 * @notice Burns a DeCup NFT
 * @param tokenId The ID of the token to burn
 * @param contractAddress The address of the DeCup contract
 * @param walletAddress The address of the wallet to burn the token from
 * @returns { success: boolean, tokenId?: bigint }
 */
const burn = async (tokenId: bigint, contractAddress: string, walletAddress: string): Promise<{ success: boolean; tokenId?: bigint }> => {

    let success = false

    try {
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'burn',
            args: [tokenId],
        })

        if (tx) {
            const receipt = await waitForTransactionReceipt(config, {
                hash: tx,
            })

            // Parse logs for Transfer event
            const logs = parseEventLogs({
                abi: DeCupABI.abi,
                logs: receipt.logs,
            });

            // Parse events to find the NFT Transfer event (mint)
            const transferEvent = logs.find(
                (log: any) =>
                    log.eventName === 'Transfer' &&
                    log.args?.tokenId === tokenId &&
                    log.args?.from?.toLowerCase() === walletAddress?.toLowerCase() &&
                    log.args?.to === '0x0000000000000000000000000000000000000000'
            );

            if ((transferEvent as any)?.args?.tokenId !== undefined) {
                const tokenId = (transferEvent as any).args.tokenId as bigint;
                console.log('Burn tokenId:', tokenId.toString());
                return {
                    success: true,
                    tokenId,
                    // transactionHash: txHash,
                };
            } else {
                console.warn('Transfer event found, but tokenId not parsed.');
                return {
                    success: true, // Transaction succeeded, but no tokenId
                    //transactionHash: txHash,
                };
            }
        }
    } catch (error) {
        console.error("Error removing DeCup NFT sale:", error)
        throw error
    }

    return { success, tokenId }
}

/**
 * @notice Validates if a sale order exists before attempting to buy
 * @param saleId The ID of the sale to check
 * @param contractAddress The address of the DeCupManager contract
 * @returns { exists: boolean, saleOrder?: any, error?: string }
 */
const validateSaleOrder = async (saleId: bigint, contractAddress: string): Promise<{ exists: boolean; saleOrder?: any; error?: string }> => {
    try {
        // Get current chain ID (assuming Sepolia for now)
        const chainId = 11155111; // Sepolia testnet

        const saleOrder = await readContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupManagerABI.abi,
            functionName: 'getSaleOrder',
            args: [chainId, Number(saleId)],
        })

        // Check if sale exists (sellerAddress is not zero address)
        const exists = saleOrder && (saleOrder as any).sellerAddress !== '0x0000000000000000000000000000000000000000';

        if (!exists) {
            return {
                exists: false,
                error: `Sale ID ${saleId.toString()} does not exist on chain ${chainId}. Please check available sales using getSaleOrderList().`
            };
        }

        return {
            exists: true,
            saleOrder: saleOrder
        };
    } catch (error) {
        console.error("Error validating sale order:", error);
        return {
            exists: false,
            error: `Failed to validate sale order: ${error}`
        };
    }
}

const buy = async (saleId: bigint, contractAddress: string, walletAddress: string, isBurn: boolean, amount: bigint): Promise<{ success: boolean; saleId?: bigint }> => {
    console.log("buy", saleId, contractAddress, walletAddress, isBurn, amount)

    // Validate sale order exists before attempting to buy
    const validation = await validateSaleOrder(saleId, contractAddress);
    if (!validation.exists) {
        throw new Error(validation.error || `Sale ID ${saleId.toString()} does not exist`);
    }

    console.log("Sale order validation passed:", validation.saleOrder);

    let success = false

    try {
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupManagerABI.abi,
            functionName: 'buy',
            value: amount,
            args: [saleId, walletAddress, isBurn],
        })

        if (tx) {
            const receipt = await waitForTransactionReceipt(config, {
                hash: tx,
            })

            // Parse logs for Transfer event
            const logs = parseEventLogs({
                abi: DeCupManagerABI.abi,
                logs: receipt.logs,
            });

            // Parse events to find the NFT Transfer event (mint)
            const transferEvent = logs.find(
                (log: any) =>
                    log.eventName === 'Buy' &&
                    log.args?.saleId === saleId &&
                    log.args?.buyerAddress?.toLowerCase() === walletAddress?.toLowerCase() &&
                    log.args?.amountPaied === amount
            );

            if ((transferEvent as any)?.args?.saleId !== undefined) {
                const saleId = (transferEvent as any).args.saleId as bigint;
                console.log('Bought tokenId:', saleId.toString());
                return {
                    success: true,
                    saleId,
                    // transactionHash: txHash,
                };
            } else {
                console.warn('Transfer event found, but tokenId not parsed.');
                return {
                    success: true, // Transaction succeeded, but no tokenId
                    //transactionHash: txHash,
                };
            }
        }
    } catch (error) {
        console.error("Error transfering NFT and removing from sale:", error)
        throw error
    }

    return { success, saleId }
}

/**
 * @notice Gets the price of a token in USD
 * @param tokenId The ID of the token
 * @param contractAddress The address of the DeCup contract
 * @returns { success: boolean, price: number }
 */
const getTokenPriceInUsd = async (tokenId: bigint, contractAddress: string): Promise<{ success: boolean; price: number }> => {

    let success = false
    let price = 0

    try {
        const tokenPrice = await readContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'getTokenPriceInUsd',
            args: [tokenId],
        })

        if (tokenPrice) {
            success = true
            price = tokenPrice as number
        }
    } catch (error) {
        console.error("Error getting token price in USD:", error)
        throw error
    }

    return { success, price }
}

/**
 * @notice Gets the collateral balance of a token
 * @param tokenId The ID of the token
 * @param contractAddress The address of the DeCup contract
 * @param tokenAddress The address of the token to get the collateral balance of
 * @returns { success: boolean, balance: number }
 */
const getCollateralBalance = async (tokenId: bigint, contractAddress: string, tokenAddress: string): Promise<{ success: boolean; balance: number }> => {
    let success = false
    let balance = 0

    try {
        const collateralBalance = await readContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'getCollateralBalance',
            args: [tokenId, tokenAddress],
        })

        if (collateralBalance) {
            success = true
            balance = collateralBalance as number
        }
    } catch (error) {
        console.error("Error getting token collateral balance:", error)
        throw error
    }

    return { success, balance }

}

/**
 * @notice Gets the NFTs minted to a wallet
 * @param contractAddress The address of the DeCup contract
 * @param walletAddress The address of the wallet to get the NFTs from
 * @returns { success: boolean, nfts: bigint[] }
 */
const getMyDeCupNfts = async (contractAddress: string, walletAddress: string): Promise<{ success: boolean; nfts: bigint[] }> => {
    try {
        const publicClient = getPublicClient(config);

        if (!publicClient) {
            throw new Error('Public client not available');
        }

        const currentBlock = await publicClient.getBlockNumber();
        const allTokenIds: bigint[] = [];

        // Use a smaller block range to avoid RPC limits (10,000 blocks at a time)
        const BLOCK_CHUNK_SIZE = 10000;
        const MAX_BLOCKS_TO_SCAN = 40000; // Scan last 40k blocks maximum

        const startBlock = currentBlock - BigInt(MAX_BLOCKS_TO_SCAN);
        const endBlock = currentBlock;

        // Query logs in chunks to avoid "exceed maximum block range" error
        for (let fromBlock = startBlock; fromBlock < endBlock; fromBlock += BigInt(BLOCK_CHUNK_SIZE)) {
            const toBlock = fromBlock + BigInt(BLOCK_CHUNK_SIZE) - BigInt(1);
            const actualToBlock = toBlock > endBlock ? endBlock : toBlock;

            try {
                console.log(`Fetching Transfer events from block ${fromBlock} to ${actualToBlock}`);

                const logs = await publicClient.getLogs({
                    address: contractAddress as `0x${string}`,
                    event: {
                        type: 'event',
                        name: 'Transfer',
                        inputs: DeCupABI.abi.find((item: any) => item.type === 'event' && item.name === 'Transfer')?.inputs || []
                    },
                    args: {
                        to: walletAddress as `0x${string}`
                    },
                    fromBlock: fromBlock,
                    toBlock: actualToBlock
                });

                // Parse the logs to extract tokenIds
                const parsedLogs = parseEventLogs({
                    abi: DeCupABI.abi,
                    logs: logs,
                });

                // Extract tokenIds from Transfer events
                for (const log of parsedLogs) {
                    if ((log as any).eventName === 'Transfer' && (log as any).args?.tokenId !== undefined) {
                        const tokenId = (log as any).args.tokenId as bigint;
                        if (!allTokenIds.includes(tokenId)) {
                            allTokenIds.push(tokenId);
                        }
                    }
                }

                // Small delay between requests to avoid rate limiting
                await new Promise(resolve => setTimeout(resolve, 100));

            } catch (chunkError) {
                console.warn(`Error fetching logs for blocks ${fromBlock}-${actualToBlock}:`, chunkError);
                // Continue with next chunk even if one fails
            }
        }

        // Filter to only include tokens still owned by the wallet
        const currentlyOwnedNfts: bigint[] = [];
        for (const tokenId of allTokenIds) {
            try {
                const currentOwner = await readContract(config, {
                    address: contractAddress as `0x${string}`,
                    abi: DeCupABI.abi,
                    functionName: 'ownerOf',
                    args: [tokenId],
                }) as string;

                if (currentOwner.toLowerCase() === walletAddress.toLowerCase()) {
                    currentlyOwnedNfts.push(tokenId);
                }
            } catch (error) {
                // Token might have been burned or doesn't exist anymore
                console.warn(`Token ${tokenId.toString()} might have been burned:`, error);
            }
        }

        console.log(`Found ${allTokenIds.length} tokens minted to wallet, ${currentlyOwnedNfts.length} currently owned`);

        return {
            success: true,
            nfts: currentlyOwnedNfts,
        };
    } catch (error) {
        console.error("Error getting DeCup NFTs:", error);
        return {
            success: false,
            nfts: [],
        };
    }
}

/**
 * @notice Gets the list of token addresses for a given tokenId
 * @param tokenId The ID of the token
 * @param contractAddress The address of the DeCup contract
 * @returns { success: boolean, tokenAddresses: string[] }
 */
const getTokenAssetsList = async (tokenId: bigint, contractAddress: string): Promise<{ success: boolean; tokenAddresses: string[] }> => {

    let success = false
    let tokenAddresses: string[] = []

    try {
        const addresses = await readContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'getTokenAssetsList',
            args: [tokenId],
        })

        if (addresses) {
            success = true
            tokenAddresses = addresses as string[]
        }
    } catch (error) {
        console.error("Error getting token assets list:", error)
        throw error
    }

    return { success, tokenAddresses }
}

/**
 * @notice Gets the list of sale orders
 * @param contractAddress The address of the DeCupManager contract
 * @returns { success: boolean, saleOrders: any[] }
 */
const getSaleOrderList = async (contractAddress: string): Promise<{ success: boolean; saleOrders: any[] }> => {
    try {
        const publicClient = getPublicClient(config);

        if (!publicClient) {
            throw new Error('Public client not available');
        }

        const currentBlock = await publicClient.getBlockNumber();
        const saleOrders: any[] = [];

        // Use a smaller block range to avoid RPC limits (10,000 blocks at a time)
        const BLOCK_CHUNK_SIZE = 10000;
        const MAX_BLOCKS_TO_SCAN = 40000; // Scan last 40k blocks maximum

        const startBlock = currentBlock - BigInt(MAX_BLOCKS_TO_SCAN);
        const endBlock = currentBlock;

        // Query logs in chunks to avoid "exceed maximum block range" error
        for (let fromBlock = startBlock; fromBlock < endBlock; fromBlock += BigInt(BLOCK_CHUNK_SIZE)) {
            const toBlock = fromBlock + BigInt(BLOCK_CHUNK_SIZE) - BigInt(1);
            const actualToBlock = toBlock > endBlock ? endBlock : toBlock;

            try {
                console.log(`Fetching CreateSale events from block ${fromBlock} to ${actualToBlock}`);

                // Query CreateSale events
                const logs = await publicClient.getLogs({
                    address: contractAddress as `0x${string}`,
                    event: {
                        type: 'event',
                        name: 'CreateSale',
                        inputs: DeCupManagerABI.abi.find((item: any) => item.type === 'event' && item.name === 'CreateSale')?.inputs || []
                    },
                    fromBlock: fromBlock,
                    toBlock: actualToBlock
                });

                // Parse the logs to extract sale orders
                const parsedLogs = parseEventLogs({
                    abi: DeCupManagerABI.abi,
                    logs: logs,
                });

                // Extract sale orders from CreateSale events
                for (const log of parsedLogs) {
                    if ((log as any).eventName === 'CreateSale' && (log as any).args) {
                        const saleOrder = {
                            saleId: (log as any).args.saleId as bigint,
                            tokenId: (log as any).args.tokenId as bigint,
                            sellerAddress: (log as any).args.sellerAddress as string,
                            sourceChainId: (log as any).args.sourceChainId as bigint,
                            destinationChainId: (log as any).args.destinationChainId as bigint,
                            priceInUsd: (log as any).args.priceInUsd as bigint,
                        };

                        // Check if this sale order already exists to avoid duplicates
                        const existingSale = saleOrders.find(order =>
                            order.saleId === saleOrder.saleId &&
                            order.tokenId === saleOrder.tokenId
                        );

                        if (!existingSale) {
                            saleOrders.push(saleOrder);
                        }
                    }
                }

                // Small delay between requests to avoid rate limiting
                await new Promise(resolve => setTimeout(resolve, 100));

            } catch (chunkError) {
                console.warn(`Error fetching CreateSale logs for blocks ${fromBlock}-${actualToBlock}:`, chunkError);
                // Continue with next chunk even if one fails
            }
        }

        console.log(`Found ${saleOrders.length} sale orders`);

        return {
            success: true,
            saleOrders: saleOrders,
        };
    } catch (error) {
        console.error("Error getting sale order list:", error);
        return {
            success: false,
            saleOrders: [],
        };
    }
}

/**
 * @notice Gets the list of canceled sale orders
 * @param contractAddress The address of the DeCupManager contract
 * @returns { success: boolean, canceldOrders: any[] }
 */
const getCanceledSaleOrderList = async (contractAddress: string): Promise<{ success: boolean; canceldOrders: any[] }> => {
    try {
        const publicClient = getPublicClient(config);

        if (!publicClient) {
            throw new Error('Public client not available');
        }

        const currentBlock = await publicClient.getBlockNumber();
        const canceldOrders: any[] = [];

        // Use a smaller block range to avoid RPC limits (10,000 blocks at a time)
        const BLOCK_CHUNK_SIZE = 10000;
        const MAX_BLOCKS_TO_SCAN = 40000; // Scan last 40k blocks maximum

        const startBlock = currentBlock - BigInt(MAX_BLOCKS_TO_SCAN);
        const endBlock = currentBlock;

        // Query logs in chunks to avoid "exceed maximum block range" error
        for (let fromBlock = startBlock; fromBlock < endBlock; fromBlock += BigInt(BLOCK_CHUNK_SIZE)) {
            const toBlock = fromBlock + BigInt(BLOCK_CHUNK_SIZE) - BigInt(1);
            const actualToBlock = toBlock > endBlock ? endBlock : toBlock;

            try {
                console.log(`Fetching CreateSale events from block ${fromBlock} to ${actualToBlock}`);

                // Query CreateSale events
                const logs = await publicClient.getLogs({
                    address: contractAddress as `0x${string}`,
                    event: {
                        type: 'event',
                        name: 'CancelSale',
                        inputs: DeCupManagerABI.abi.find((item: any) => item.type === 'event' && item.name === 'CancelSale')?.inputs || []
                    },
                    fromBlock: fromBlock,
                    toBlock: actualToBlock
                });

                // Parse the logs to extract sale orders
                const parsedLogs = parseEventLogs({
                    abi: DeCupManagerABI.abi,
                    logs: logs,
                });

                // Extract sale orders from CreateSale events
                for (const log of parsedLogs) {
                    if ((log as any).eventName === 'CancelSale' && (log as any).args) {
                        const canceldOrder = {
                            saleId: (log as any).args.saleId as bigint,
                        };

                        // Check if this sale order already exists to avoid duplicates
                        const existingSale = canceldOrders.find(order =>
                            order.saleId === canceldOrder.saleId
                        );

                        if (!existingSale) {
                            canceldOrders.push(canceldOrder);
                        }
                    }
                }

                // Small delay between requests to avoid rate limiting
                await new Promise(resolve => setTimeout(resolve, 100));

            } catch (chunkError) {
                console.warn(`Error fetching CreateSale logs for blocks ${fromBlock}-${actualToBlock}:`, chunkError);
                // Continue with next chunk even if one fails
            }
        }

        console.log(`Found ${canceldOrders.length} canceld orders`);

        return {
            success: true,
            canceldOrders: canceldOrders,
        };
    } catch (error) {
        console.error("Error getting sale order list:", error);
        return {
            success: false,
            canceldOrders: [],
        };
    }
}

/**
 * @notice Gets the collateral balance of a token in ETH
 * @param saleId The ID of the sale
 * @param contractAddress The address of the DeCupManager contract
 * @returns { success: boolean, collateralEth: number }
 */
const getCcipCollateralInEth = async (saleId: bigint, contractAddress: string): Promise<{ success: boolean; collateralEth: number }> => {

    let success = false
    let collateralEth = 0

    try {
        const collateral = await readContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupManagerABI.abi,
            functionName: 'getCcipCollateralInEth',
            args: [],
        })

        if (collateral) {
            success = true
            collateralEth = collateral as number
        }
    } catch (error) {
        console.error("Error getting sale order price in ETH:", error)
        throw error
    }

    return { success, collateralEth }
}

/**
 * @notice Gets the collateral balance of a token in USD
 * @param contractAddress The address of the DeCup contract
 * @returns { success: boolean, collateralUsd: number }
 */
const getCcipCollateralInUsd = async (contractAddress: string): Promise<{ success: boolean; collateralUsd: number }> => {

    let success = false
    let collateralUsd = 0

    try {
        const collateral = await readContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupManagerABI.abi,
            functionName: 'getCcipCollateralInUsd',
            args: [],
        })

        if (collateral) {
            success = true
            collateralUsd = collateral as number
        }
    } catch (error) {
        console.error("Error getting sale order price in USD:", error)
        throw error
    }

    return { success, collateralUsd }
}

/**
 * @notice Gets the price of a token in ETH
 * @param priceInUsd The price of the token in USD
 * @param contractAddress The address of the DeCupManager contract
 * @returns { success: boolean, priceInEth: number }
 */
const getPriceInETH = async (priceInUsd: number, contractAddress: string): Promise<{ success: boolean; priceInEth: number }> => {
    let success = false
    let priceInEth = 0

    try {
        const price = await readContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupManagerABI.abi,
            functionName: 'getPriceInETH',
            args: [priceInUsd],
        })

        if (price) {
            success = true
            priceInEth = price as number
        }
    } catch (error) {
        console.error("Error getting sale order price in ETH:", error)
        throw error
    }

    return { success, priceInEth }

}

/**
 * @notice Gets if a token is listed for sale
 * @param tokenId The ID of the token
 * @param contractAddress The address of the DeCup contract
 * @returns { success: boolean, isListed: boolean }
 */
const getIsListedForSale = async (tokenId: number, contractAddress: string): Promise<{ success: boolean, isListed: boolean }> => {
    let success = false
    let isListed = false

    try {
        const listed = await readContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'getIsListedForSale',
            args: [tokenId],
        })

        if (listed) {
            success = true
            isListed = listed as boolean
        }
    } catch (error) {
        console.error("Error getting token is listed for sale:", error)
        throw error
    }

    return { success, isListed }

}
/**
 * @notice Gets the sale order for a given chainId and saleId
 * @param chainId The ID of the chain
 * @param saleId The ID of the sale
 * @param contractAddress The address of the DeCupManager contract
 * @returns { success: boolean, saleOrder: any }
 */
const getSaleOrder = async (chainId: number, saleId: number, contractAddress: string): Promise<{ success: boolean, saleOrder: any }> => {
    let success = false
    let saleOrder: any

    try {
        const order = await readContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupManagerABI.abi,
            functionName: 'getSaleOrder',
            args: [chainId, saleId],
        })

        if (order) {
            success = true
            saleOrder = order as any
        }
    } catch (error) {
        console.error("Error getting token is listed for sale:", error)
        throw error
    }

    return { success, saleOrder }
}

export {
    depositNative,
    depositERC20,
    withdrawNativeDeCupManager,
    burnDeCupNFT,
    createSale,
    cancelSale,
    getTokenPriceInUsd,
    getMyDeCupNfts,
    getTokenAssetsList,
    getSaleOrderList,
    getCcipCollateralInEth,
    getCcipCollateralInUsd,
    getPriceInETH,
    getIsListedForSale,
    getSaleOrder,
    getCanceledSaleOrderList,
    burn,
    addTokenCollateralToExistingCup,
    addNativeCollateralToExistingCup,
    getCollateralBalance,
    buy,
    validateSaleOrder
}