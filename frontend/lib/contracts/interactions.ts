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

const createSale = async (tokenId: bigint, beneficialWallet: string, contractAddress: string): Promise<boolean> => {

    let success = false

    try {
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'createSale',
            args: [tokenId, beneficialWallet],
        })

        if (tx) {
            success = true
        }
    } catch (error) {
        console.error("Error create DeCup NFT Manager sale for a token:", error)
        throw error
    }

    return success
}

const cancelSale = async (saleId: bigint, contractAddress: string): Promise<boolean> => {

    let success = false

    try {
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'cancelSale',
            args: [saleId],
        })

        if (tx) {
            success = true
        }
    } catch (error) {
        console.error("Error removing DeCup NFT sale:", error)
        throw error
    }

    return success
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

        // Query Transfer events where 'to' is the wallet address (minted to this wallet)
        const logs = await publicClient.getLogs({
            address: contractAddress as `0x${string}`,
            event: {
                type: 'event',
                name: 'Transfer',
                inputs: [
                    { name: 'from', type: 'address', indexed: true },
                    { name: 'to', type: 'address', indexed: true },
                    { name: 'tokenId', type: 'uint256', indexed: true }
                ]
            },
            args: {
                to: walletAddress as `0x${string}`
            },
            fromBlock: BigInt(await publicClient.getBlockNumber()) - BigInt(50000),
            toBlock: 'latest'
        });

        // Parse the logs to extract tokenIds
        const allTokenIds: bigint[] = [];
        const parsedLogs = parseEventLogs({
            abi: DeCupABI.abi,
            logs: logs,
        });

        // Extract tokenIds from Transfer events
        for (const log of parsedLogs) {
            if ((log as any).eventName === 'Transfer' && (log as any).args?.tokenId !== undefined) {
                const tokenId = (log as any).args.tokenId as bigint;
                allTokenIds.push(tokenId);
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
export {
    depositNative,
    depositERC20,
    withdrawNativeDeCupManager,
    burnDeCupNFT,
    createSale,
    cancelSale,
    getTokenPriceInUsd,
    getMyDeCupNfts,
    getTokenAssetsList
}