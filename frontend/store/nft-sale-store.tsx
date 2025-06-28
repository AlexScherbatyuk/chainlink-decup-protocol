"use client"

import { create } from "zustand"
import { devtools, persist } from "zustand/middleware"

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
    price: number
    totalCollateral: number
    assets: Asset[]
    chain: "Sepolia" | "AvalancheFuji"
    icon: string
    beneficialWallet: string
    createdAt: Date
    updatedAt: Date
}

export interface NFTSaleFormData {
    saleId?: number
    price: number
    assets: Asset[]
    chain: "Sepolia" | "AvalancheFuji"
    beneficialWallet: string
}

interface NFTSaleStore {
    // Data
    onSaleNfts: DeCupNFTSale[]

    // Actions
    createNFTSale: (data: NFTSaleFormData) => DeCupNFTSale
    updateNFTSale: (id: string, data: Partial<NFTSaleFormData>) => boolean
    deleteNFTSale: (id: string) => boolean

    // Utilities
    getNFTSaleById: (id: string) => DeCupNFTSale | undefined
    getNFTSaleBySaleId: (saleId: number) => DeCupNFTSale | undefined
    getTotalCollateral: (assets: Asset[]) => number
    generateSaleId: () => number
    clearAllData: () => void
}

export const useNFTSaleStore = create<NFTSaleStore>()(
    devtools(
        persist(
            (set, get) => ({
                // Initialize with empty data
                onSaleNfts: [],

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
                        price: data.price,
                        totalCollateral: state.getTotalCollateral(data.assets),
                        assets: data.assets,
                        chain: data.chain,
                        icon: `/placeholder.svg?height=40&width=40&query=DeCup Sale ${saleId}`,
                        beneficialWallet: data.beneficialWallet,
                        createdAt: new Date(),
                        updatedAt: new Date(),
                    }

                    set((state) => ({
                        onSaleNfts: [...state.onSaleNfts, newNFTSale],
                    }))

                    return newNFTSale
                },

                updateNFTSale: (id: string, data: Partial<NFTSaleFormData>) => {
                    const state = get()
                    const index = state.onSaleNfts.findIndex((nftSale) => nftSale.id === id)

                    if (index === -1) return false

                    const updatedNFTSale = {
                        ...state.onSaleNfts[index],
                        ...data,
                        totalCollateral: data.assets ? state.getTotalCollateral(data.assets) : state.onSaleNfts[index].totalCollateral,
                        updatedAt: new Date(),
                    }

                    set((state) => {
                        const newOnSaleNfts = [...state.onSaleNfts]
                        newOnSaleNfts[index] = updatedNFTSale
                        return { onSaleNfts: newOnSaleNfts }
                    })

                    return true
                },

                deleteNFTSale: (id: string) => {
                    const state = get()
                    const index = state.onSaleNfts.findIndex((nftSale) => nftSale.id === id)

                    if (index === -1) return false

                    set((state) => ({
                        onSaleNfts: state.onSaleNfts.filter((nftSale) => nftSale.id !== id),
                    }))

                    return true
                },

                // Utilities
                getNFTSaleById: (id: string) => {
                    const state = get()
                    return state.onSaleNfts.find((nftSale) => nftSale.id === id)
                },

                getNFTSaleBySaleId: (saleId: number) => {
                    const state = get()
                    return state.onSaleNfts.find((nftSale) => nftSale.saleId === saleId)
                },

                getTotalCollateral: (assets: Asset[]) => {
                    return assets.reduce((sum, asset) => sum + asset.amount, 0)
                },

                generateSaleId: () => {
                    const state = get()
                    const maxSaleId = Math.max(...state.onSaleNfts.map((nftSale) => nftSale.saleId), 0)
                    return maxSaleId + 1
                },

                clearAllData: () => {
                    set({
                        onSaleNfts: [],
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