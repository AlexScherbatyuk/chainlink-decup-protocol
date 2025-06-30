"use client"

import { createContext, useContext, useEffect, useState, useRef, ReactNode } from 'react'
import { useAccount, useChainId } from 'wagmi'
import { useNFTStore } from '@/store/nft-store'
import { useNFTSaleStore } from '@/store/nft-sale-store'
import {
    getMyDeCupNfts,
    getTokenPriceInUsd,
    getAssetsInfo,
    getIsListedForSale,
    getSaleOrderList,
    getCanceledSaleOrderList,
    getPriceInETH,
    getSaleOrder,
    getBurnedNftList,
    getBoughtSaleOrders,
    getCanceledCrossSaleOrderList,
    getBoughtCrossSaleOrders,
    getDeletedSaleOrders,
    getCreateCrossSaleOrderList
} from '@/lib/contracts/interactions'
import { getContractAddresses } from '@/lib/contracts/addresses'
import { getChainNameById, getChainIds } from '@/lib/contracts/chains'

interface NFTContextType {
    isLoading: boolean
    isFetching: boolean
    isFetchingSales: boolean
    error: string | null
    refetch: (forceClear?: boolean) => Promise<void>
    refetchSales: (forceClear?: boolean) => Promise<void>
}

const NFTContext = createContext<NFTContextType | undefined>(undefined)

interface NFTProviderProps {
    children: ReactNode
}

export function NFTProvider({ children }: NFTProviderProps) {
    const { address, isConnected } = useAccount()
    const chainId = useChainId()

    const { myListNfts, clearNftStoreData, createNFT, checkIfNFTExistsByTokenId } = useNFTStore()
    const { listedSales, clearSaleStoreData, createNFTSale, getNFTSaleBySaleId } = useNFTSaleStore()

    const [isLoading, setIsLoading] = useState(false)
    const [isFetching, setIsFetching] = useState(false)
    const [isFetchingSales, setIsFetchingSales] = useState(false)
    const [error, setError] = useState<string | null>(null)

    // Use ref to prevent race conditions
    const fetchingRef = useRef(false)
    const fetchingSalesRef = useRef(false)
    const lastFetchKey = useRef<string>('')
    const lastSalesFetchKey = useRef<string>('')

    // Format asset amount
    const formatAssetAmount = (amount: Number) => {
        return parseFloat(((amount ? Number(amount) : 0) / 10 ** 18).toFixed(2))
    }

    // Fetch my DeCup NFTs from the contract
    const fetchMyDeCupNfts = async () => {
        if (!isConnected || !address || !chainId) {
            return
        }

        const fetchKey = `${chainId}-${address}`

        // Prevent duplicate fetches
        if (fetchingRef.current || lastFetchKey.current === fetchKey) {
            console.log('Skipping fetch - already in progress or already fetched for this key')
            return
        }

        fetchingRef.current = true
        lastFetchKey.current = fetchKey
        setIsFetching(true)
        setError(null)

        try {
            console.log('Starting NFT fetch for chain:', chainId, 'address:', address)

            const { success, nfts } = await getMyDeCupNfts(
                getContractAddresses[chainId as keyof typeof getContractAddresses].DeCup,
                address as `0x${string}`
            )

            // Get burned NFTs
            const { success: successBurnedNfts, burnedNfts } = await getBurnedNftList(
                getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager
            )

            if (!successBurnedNfts) {
                console.error("Failed to get burned NFTs")
                return
            }

            // Filter out burned NFTs from NFTs
            const burnedNftIds = new Set(burnedNfts?.map(nft => Number(nft)) || [])
            const activeNfts = nfts?.filter(nft => !burnedNftIds.has(Number(nft))) || []

            const { success: successCreateCrossSaleOrderList, crossSaleOrders } = await getCreateCrossSaleOrderList(
                getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager
            )

            if (success && activeNfts.length > 0) {
                console.log(`Found ${activeNfts.length} active NFTs:`, activeNfts)

                for (const tokenId of activeNfts) {
                    // Skip if already exists in store
                    if (checkIfNFTExistsByTokenId(Number(tokenId))) {
                        console.log(`NFT ${tokenId} already exists in store, skipping`)
                        continue
                    }
                    //244 6923 6340
                    const totalCollateral = await getTokenPriceInUsd(
                        tokenId,
                        getContractAddresses[chainId as keyof typeof getContractAddresses].DeCup
                    )

                    const { success: successCheck, assetsInfo } = await getAssetsInfo(
                        BigInt(tokenId),
                        getContractAddresses[chainId as keyof typeof getContractAddresses].DeCup
                    )

                    const { success: successIsListed, isListed } = await getIsListedForSale(
                        Number(tokenId),
                        getContractAddresses[chainId as keyof typeof getContractAddresses].DeCup
                    )


                    const tokenPriceInUsdDisplay = parseFloat((Number(totalCollateral.price) / 10 ** 8).toFixed(2))

                    console.log(`Creating NFT ${tokenId} with price ${tokenPriceInUsdDisplay}`)

                    const destinationChainId = crossSaleOrders.find(order => order.tokenId === tokenId)?.destinationChainId ?? chainId

                    console.log("destinationChainId", destinationChainId)
                    createNFT({
                        tokenId: Number(tokenId),
                        price: tokenPriceInUsdDisplay,
                        totalCollateral: tokenPriceInUsdDisplay,
                        assets: assetsInfo.map((asset, index) => ({
                            id: index.toString(),
                            token: asset.split(" ")[0] ?? "",
                            amount: formatAssetAmount(Number(asset.split(" ")[1]) ?? 0),
                            walletAddress: address as `0x${string}`,
                            deposited: true
                        })),
                        chain: getChainNameById[chainId as keyof typeof getChainNameById] as "Sepolia" | "AvalancheFuji",
                        destinationChain: getChainNameById[Number(destinationChainId) as keyof typeof getChainNameById] as "Sepolia" | "AvalancheFuji",
                        beneficialWallet: address as `0x${string}`,
                        isListedForSale: isListed || false
                    })
                }
            } else {
                console.log('No NFTs found or fetch failed')
            }
        } catch (error) {
            console.error('Error fetching NFTs:', error)
            setError(error instanceof Error ? error.message : 'Failed to fetch NFTs')
        } finally {
            setIsFetching(false)
            fetchingRef.current = false
        }
    }

    // Fetch sale orders from the contract
    const fetchSaleOrders = async () => {
        if (!isConnected || !address || !chainId) {
            return
        }

        const fetchKey = `${chainId}-sales`

        // Prevent duplicate fetches
        if (fetchingSalesRef.current || lastSalesFetchKey.current === fetchKey) {
            console.log('Skipping sales fetch - already in progress or already fetched for this key')
            return
        }

        fetchingSalesRef.current = true
        lastSalesFetchKey.current = fetchKey
        setIsFetchingSales(true)
        setError(null)

        try {
            console.log('Starting sale orders fetch for chain:', chainId)

            // Get sale orders
            const { success, saleOrders } = await getSaleOrderList(
                getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager
            )


            if (!success) {
                console.error("Failed to get sale orders")
                return
            }

            console.log("saleOrders", saleOrders)

            // Get canceled sale orders
            // const { success: successCanceledOrders, canceldOrders } = await getCanceledSaleOrderList(
            //     getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager
            // )

            // if (!successCanceledOrders) {
            //     console.error("Failed to get canceled sale orders")
            //     return
            // }

            // const { success: successCanceledCrossOrders, canceldCrossOrders } = await getCanceledCrossSaleOrderList(
            //     getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager
            // )

            // const { success: successBoughtOrders, boughtOrders } = await getBoughtSaleOrders(
            //     getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager
            // )

            // const { success: successBoughtCrossOrders, boughtCrossOrders } = await getBoughtCrossSaleOrders(
            //     getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager
            // )

            // if (!successBoughtOrders) {
            //     console.error("Failed to get bought sale orders")
            //     return
            // }

            // if (!successCanceledCrossOrders) {
            //     console.error("Failed to get canceled cross sale orders")
            //     return
            // }

            // if (!successBoughtCrossOrders) {
            //     console.error("Failed to get bought cross sale orders")
            //     return
            // }


            // Filter out canceled orders from sale orders
            // const canceledOrderIds = new Set(canceldOrders?.map(order => Number(order.saleId)) || [])
            // const activeSaleOrdersNoCanceled = saleOrders?.filter(order => !canceledOrderIds.has(Number(order.saleId))) || []

            // const canceledCrossOrderIds = new Set(canceldCrossOrders?.map(order => Number(order.saleId)) || [])
            // const activeCrossSaleOrdersNoCanceled = activeSaleOrdersNoCanceled?.filter(order => !canceledCrossOrderIds.has(Number(order.saleId))) || []

            // const boughtOrdersIds = new Set(boughtOrders?.map(order => Number(order.saleId)) || [])
            // const activeBoughtOrders = activeCrossSaleOrdersNoCanceled?.filter(order => !boughtOrdersIds.has(Number(order.saleId))) || []

            // const boughtCrossOrdersIds = new Set(boughtCrossOrders?.map(order => Number(order.saleId)) || [])
            // const activeBoughtCrossOrders = activeBoughtOrders?.filter(order => !boughtCrossOrdersIds.has(Number(order.saleId))) || []


            //const activeSaleOrders = [...activeBoughtCrossOrders]

            const { success: successDeletedOrders, deletedOrders } = await getDeletedSaleOrders(
                getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager
            )

            if (!successDeletedOrders) {
                console.error("Failed to get deleted sale orders")
                return
            }

            const deletedOrderIds = new Set(deletedOrders?.map(order => Number(order.saleId)) || [])
            const activeSaleOrders = saleOrders?.filter(order => !deletedOrderIds.has(Number(order.saleId))) || []

            console.log(`Found ${activeSaleOrders.length} active sale orders`)

            for (const saleOrder of activeSaleOrders) {
                // Skip if already exists in store by saleId
                const existingSaleById = getNFTSaleBySaleId(Number(saleOrder.saleId))
                if (existingSaleById) {
                    console.log(`Sale ${saleOrder.saleId} already exists in store, skipping`)
                    continue
                }

                //const chainName = getChainNameById[Number(saleOrder.sourceChainId) as keyof typeof getChainNameById]
                const chainName = getChainNameById[Number(saleOrder.destinationChainId) as keyof typeof getChainNameById] as "Sepolia" | "AvalancheFuji";
                console.log("chainName", chainName)


                const tokenPriceInUsd = saleOrder.priceInUsd
                const { success: successEth, priceInEth } = await getPriceInETH(
                    tokenPriceInUsd,
                    getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager
                )

                const tokenPriceInUsdDisplay = parseFloat((Number(tokenPriceInUsd) / 10 ** 8).toFixed(2))
                const priceInEthDisplay = parseFloat(((successEth ? Number(priceInEth) : 0) / 10 ** 18).toFixed(2))


                const saleOrderChainId = saleOrder.sourceChainId !== saleOrder.destinationChainId ? saleOrder.destinationChainId : saleOrder.sourceChainId
                console.log("saleOrderChainId", saleOrderChainId)
                const { success: successCheck, saleOrder: saleOrderData } = await getSaleOrder(
                    saleOrderChainId,
                    Number(saleOrder.saleId),
                    getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager
                )


                if (!saleOrderData) {
                    console.log(`Failed to get sale order data for ${saleOrder.saleId}, skipping`)
                    continue
                }

                console.log(`Creating sale order ${saleOrder.saleId} with price ${tokenPriceInUsdDisplay}`)
                console.log("saleOrderData", saleOrderData)
                console.log("saleId", saleOrder.saleId)
                console.log("source chainId", saleOrder.sourceChainId)
                console.log("destination chainId", saleOrder.destinationChainId)

                createNFTSale({
                    saleId: Number(saleOrder.saleId),
                    price: priceInEthDisplay,
                    assets: saleOrderData.assetsInfo.map((asset: string, index: number) => ({
                        id: index.toString(),
                        token: asset.split(" ")[0] ?? "",
                        amount: formatAssetAmount(Number(asset.split(" ")[1]) ?? 0),
                        walletAddress: saleOrder.sellerAddress as `0x${string}`,
                        deposited: true
                    })),
                    totalCollateral: tokenPriceInUsdDisplay,
                    chain: getChainNameById[Number(saleOrder.sourceChainId) as keyof typeof getChainNameById] as "Sepolia" | "AvalancheFuji",
                    destinationChain: getChainNameById[Number(saleOrder.destinationChainId) as keyof typeof getChainNameById] as "Sepolia" | "AvalancheFuji",
                    beneficialWallet: saleOrder.beneficiaryAddress
                })
            }
        } catch (error) {
            console.error('Error fetching sale orders:', error)
            setError(error instanceof Error ? error.message : 'Failed to fetch sale orders')
        } finally {
            setIsFetchingSales(false)
            fetchingSalesRef.current = false
        }
    }

    // Refetch function for manual refresh
    const refetch = async (forceClear = false) => {
        // Reset the fetch key to allow refetch
        lastFetchKey.current = ''
        // Only clear data if explicitly requested
        if (forceClear) {
            clearNftStoreData()
        }
        await fetchMyDeCupNfts()
    }

    // Refetch sales function for manual refresh
    const refetchSales = async (forceClear = false) => {
        // Reset the fetch key to allow refetch
        lastSalesFetchKey.current = ''
        // Only clear data if explicitly requested
        if (forceClear) {
            clearSaleStoreData()
        }
        await fetchSaleOrders()
    }

    // Main effect to handle connection changes
    useEffect(() => {
        if (isConnected && address && chainId) {
            console.log('NFT Context: Connected, clearing stores and fetching fresh data')
            // Clear stores and fetch fresh data on page load/refresh
            clearNftStoreData()
            clearSaleStoreData()
            fetchMyDeCupNfts()
            fetchSaleOrders()
        } else {
            console.log('NFT Context: Disconnected, clearing data')
            clearNftStoreData()
            clearSaleStoreData()
            fetchingRef.current = false
            fetchingSalesRef.current = false
            lastFetchKey.current = ''
            lastSalesFetchKey.current = ''
            setError(null)
        }
    }, [chainId, address, isConnected])

    const value: NFTContextType = {
        isLoading,
        isFetching,
        isFetchingSales,
        error,
        refetch,
        refetchSales
    }

    return (
        <NFTContext.Provider value={value}>
            {children}
        </NFTContext.Provider>
    )
}

export function useNFTContext() {
    const context = useContext(NFTContext)
    if (context === undefined) {
        throw new Error('useNFTContext must be used within a NFTProvider')
    }
    return context
} 