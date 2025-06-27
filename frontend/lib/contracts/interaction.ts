import { sendTransaction, readContract, writeContract, waitForTransactionReceipt } from '@wagmi/core'
import { config } from '@/config'
import { erc20Abi, parseEventLogs } from 'viem'
import { DeCupManagerABI, DeCupABI } from '@/lib/contracts/abis'

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

const listDeCupNFTForSale = async (tokenId: bigint, contractAddress: string): Promise<boolean> => {

    let success = false

    try {
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'listForSale',
            args: [tokenId],
        })

        if (tx) {
            success = true
        }
    } catch (error) {
        console.error("Error listing DeCup NFT for sale:", error)
        throw error
    }

    return success
}

const removeDeCupNFTFromSale = async (tokenId: bigint, contractAddress: string): Promise<boolean> => {

    let success = false

    try {
        const tx = await writeContract(config, {
            address: contractAddress as `0x${string}`,
            abi: DeCupABI.abi,
            functionName: 'removeFromSale',
            args: [tokenId],
        })

        if (tx) {
            success = true
        }
    } catch (error) {
        console.error("Error removing DeCup NFT from sale:", error)
        throw error
    }

    return success
}

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

export {
    depositNative,
    depositERC20,
    withdrawNativeDeCupManager,
    burnDeCupNFT,
    listDeCupNFTForSale,
    removeDeCupNFTFromSale,
    getTokenPriceInUsd
}