"use client"

import { create } from "zustand"
import { devtools, persist } from "zustand/middleware"
import { getChainIdByName } from "@/lib/contracts/chains"

export interface Asset {
    id: string
    token: string
    amount: number
    walletAddress: string
    deposited: boolean
}

export interface DeCupNFTSale {
    id: string
    saleId: number
    tokenId: number
    price: number
    totalCollateral: number
    assets: Asset[]
    chain: "Sepolia" | "AvalancheFuji"
    destinationChain: "Sepolia" | "AvalancheFuji"
    icon: string
    beneficialWallet: string
    createdAt: Date
    updatedAt: Date
}

export interface NFTSaleFormData {
    saleId?: number
    tokenId?: number
    price: number
    assets: Asset[]
    chain: "Sepolia" | "AvalancheFuji"
    destinationChain: "Sepolia" | "AvalancheFuji"
    beneficialWallet: string
    totalCollateral?: number
}

interface NFTSaleStore {
    // Data
    listedSales: DeCupNFTSale[]

    // Actions
    createNFTSale: (data: NFTSaleFormData) => DeCupNFTSale
    updateNFTSale: (id: string, data: Partial<NFTSaleFormData>) => boolean
    deleteNFTSale: (id: string) => boolean
    deleteNFTSaleByTokenId: (tokenId: number) => boolean

    // Utilities
    getNFTSaleById: (id: string) => DeCupNFTSale | undefined
    getNFTSaleBySaleId: (saleId: number) => DeCupNFTSale | undefined
    getNFTSaleByChainIdTokenId: (chain: "Sepolia" | "AvalancheFuji", tokenId: number) => DeCupNFTSale | undefined
    getTotalCollateral: (assets: Asset[]) => number
    generateSaleId: () => number
    clearSaleStoreData: () => void
}

export const useNFTSaleStore = create<NFTSaleStore>()(
    devtools(
        persist(
            (set, get) => ({
                // Initialize with empty data
                listedSales: [],

                // Actions
                createNFTSale: (data: NFTSaleFormData) => {
                    const state = get()

                    // Check if NFT sale with this saleId already exists
                    if (data.saleId) {
                        const existingNFTSale = state.getNFTSaleBySaleId(data.saleId)
                        if (existingNFTSale) {
                            // Update existing NFT sale instead of creating new one
                            const success = state.updateNFTSale(existingNFTSale.id, data)
                            if (success) {
                                // Return the updated NFT sale
                                return state.getNFTSaleBySaleId(data.saleId)!
                            }
                        }
                    }

                    // Create new NFT sale if no existing one found
                    const saleId = data.saleId || state.generateSaleId()
                    const newNFTSale: DeCupNFTSale = {
                        id: `nft-sale-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
                        saleId: saleId,
                        tokenId: data.tokenId || 0,
                        price: data.price,
                        totalCollateral: data.totalCollateral || state.getTotalCollateral(data.assets),
                        assets: data.assets,
                        chain: data.chain,
                        destinationChain: data.destinationChain,
                        icon: `/placeholder.svg?height=40&width=40&query=DeCup Sale ${saleId}`,
                        beneficialWallet: data.beneficialWallet,
                        createdAt: new Date(),
                        updatedAt: new Date(),
                    }

                    set((state) => ({
                        listedSales: [...state.listedSales, newNFTSale],
                    }))

                    return newNFTSale
                },

                updateNFTSale: (id: string, data: Partial<NFTSaleFormData>) => {
                    const state = get()
                    const index = state.listedSales.findIndex((nftSale) => nftSale.id === id)

                    if (index === -1) return false

                    const updatedNFTSale = {
                        ...state.listedSales[index],
                        ...data,
                        totalCollateral: data.assets ? state.getTotalCollateral(data.assets) : state.listedSales[index].totalCollateral,
                        updatedAt: new Date(),
                    }

                    set((state) => {
                        const newOnSaleNfts = [...state.listedSales]
                        newOnSaleNfts[index] = updatedNFTSale
                        return { listedSales: newOnSaleNfts }
                    })

                    return true
                },

                deleteNFTSale: (id: string) => {
                    const state = get()
                    const index = state.listedSales.findIndex((nftSale) => nftSale.id === id)

                    if (index === -1) return false

                    set((state) => ({
                        listedSales: state.listedSales.filter((nftSale) => nftSale.id !== id),
                    }))

                    return true
                },

                deleteNFTSaleByTokenId: (tokenId: number) => {
                    const state = get()
                    const index = state.listedSales.findIndex((nftSale) => nftSale.tokenId === tokenId)

                    if (index === -1) return false

                    set((state) => ({
                        listedSales: state.listedSales.filter((nftSale) => nftSale.tokenId !== tokenId),
                    }))

                    return true
                },

                // Utilities
                getNFTSaleById: (id: string) => {
                    const state = get()
                    return state.listedSales.find((nftSale) => nftSale.id === id)
                },

                getNFTSaleBySaleId: (saleId: number) => {
                    const state = get()
                    return state.listedSales.find((nftSale) => nftSale.saleId === saleId)
                },

                getNFTSaleByChainIdTokenId: (chain: "Sepolia" | "AvalancheFuji", tokenId: number) => {
                    const state = get()
                    return state.listedSales.find((nftSale) => nftSale.chain === chain && BigInt(nftSale.tokenId) === BigInt(tokenId))
                },

                getTotalCollateral: (assets: Asset[]) => {
                    return assets.reduce((sum, asset) => sum + asset.amount, 0)
                },

                generateSaleId: () => {
                    const state = get()
                    if (state.listedSales.length === 0) {
                        return 0
                    }
                    const maxSaleId = Math.max(...state.listedSales.map((nftSale) => nftSale.saleId))
                    return maxSaleId + 1
                },

                clearSaleStoreData: () => {
                    set({
                        listedSales: [],
                    })
                    console.log("🗑️ All data cleared from DeCup NFT Sale store")
                },
            }),
            {
                name: "decup-nft-sale-store",
            },
        ),
        {
            name: "decup-nft-sale-store",
        },
    ),
) 