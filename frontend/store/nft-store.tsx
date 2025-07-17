"use client"

import { custLog } from "@/lib/utils"
import { create } from "zustand"
import { devtools, persist } from "zustand/middleware"

export interface Asset {
  id: string
  token: string
  amount: number
  walletAddress: string
  deposited: boolean
}

export interface DeCupNFT {
  id: string
  tokenId: number
  price: number
  marketPrice?: boolean
  totalCollateral: number
  assets: Asset[]
  chain: "Sepolia" | "AvalancheFuji"
  destinationChain: "Sepolia" | "AvalancheFuji"
  icon: string
  isListedForSale?: boolean
  beneficialWallet: string
  createdAt: Date
  updatedAt: Date
}

export interface NFTFormData {
  tokenId?: number
  price: number
  marketPrice?: boolean
  totalCollateral: number
  assets: Asset[]
  chain: "Sepolia" | "AvalancheFuji"
  destinationChain: "Sepolia" | "AvalancheFuji"
  beneficialWallet: string
  isListedForSale?: boolean
}

interface NFTStore {
  // Data
  myListNfts: DeCupNFT[]

  // Actions
  createNFT: (data: NFTFormData) => DeCupNFT
  updateNFT: (id: string, data: Partial<NFTFormData>) => boolean
  updateNFTByTokenId: (tokenId: number, data: Partial<NFTFormData>) => boolean
  deleteNFT: (id: string) => boolean
  deleteNFTByTokenId: (tokenId: number) => boolean
  toggleListing: (id: string) => boolean
  toggleListingByTokenId: (tokenId: number) => boolean
  clearNftStoreData: () => void

  // Utilities
  getNFTById: (id: string) => DeCupNFT | undefined
  getTotalCollateral: (assets: Asset[]) => number
  generateTokenId: () => number
  checkIfNFTExists: (id: string) => boolean
  checkIfNFTExistsByTokenId: (tokenId: number) => boolean
  getNFTByTokenId: (tokenId: number) => DeCupNFT | undefined
}

export const useNFTStore = create<NFTStore>()(
  devtools(
    persist(
      (set, get) => ({
        // Initialize with empty data
        myListNfts: [],

        // Check if NFT exists
        checkIfNFTExists: (id: string) => {
          const state = get()
          return state.myListNfts.some((nft) => nft.id === id)
        },

        // Get NFT by tokenId
        getNFTByTokenId: (tokenId: number) => {
          const state = get()
          return state.myListNfts.find((nft) => nft.tokenId === tokenId)
        },

        // Actions
        createNFT: (data: NFTFormData) => {
          const state = get()
          custLog('debug', '[nft-store] createNFT', data)
          // Check if NFT with this tokenId already exists
          if (data.tokenId) {
            custLog('debug', '[nft-store] data.tokenId', data.tokenId)
            const existingNFT = state.getNFTByTokenId(data.tokenId)
            if (existingNFT) {
              custLog('debug', '[nft-store] data.tokenId', data.tokenId)
              // Update existing NFT instead of creating new one
              const success = state.updateNFT(existingNFT.id, data)
              if (success) {
                custLog('debug', '[nft-store] data.tokenId', data.tokenId)
                // Return the updated NFT
                return state.getNFTByTokenId(data.tokenId)!
              }
            }
          }

          custLog('debug', '[nft-store] Continue creating NFT')
          // Create new NFT if no existing one found
          const tokenId = typeof data.tokenId === 'number' && data.tokenId >= 0 ? data.tokenId : state.generateTokenId()
          const newNFT: DeCupNFT = {
            id: `nft-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
            tokenId: tokenId,
            price: data.price,
            marketPrice: data.marketPrice,
            totalCollateral: data.totalCollateral || state.getTotalCollateral(data.assets),
            assets: data.assets,
            chain: data.chain,
            destinationChain: data.destinationChain,
            icon: `/placeholder.svg?height=40&width=40&query=DeCup NFT ${tokenId}`,
            isListedForSale: data.isListedForSale || false,
            beneficialWallet: data.beneficialWallet,
            createdAt: new Date(),
            updatedAt: new Date(),
          }

          set((state) => ({
            myListNfts: [...state.myListNfts, newNFT],
          }))

          return newNFT
        },

        updateNFT: (id: string, data: Partial<NFTFormData>) => {
          const state = get()
          const index = state.myListNfts.findIndex((nft) => nft.id === id)
          if (index === -1) return false

          const updatedNFT = {
            ...state.myListNfts[index],
            ...data,
            totalCollateral: data.assets ? state.getTotalCollateral(data.assets) : state.myListNfts[index].totalCollateral,
            updatedAt: new Date(),
          }

          set((state) => {
            const newMyListNfts = [...state.myListNfts]
            newMyListNfts[index] = updatedNFT
            return { myListNfts: newMyListNfts }
          })

          return true
        },

        updateNFTByTokenId: (tokenId: number, data: Partial<NFTFormData>) => {
          const state = get()
          const index = state.myListNfts.findIndex((nft) => nft.tokenId === tokenId)
          if (index === -1) return false

          const updatedNFT = {
            ...state.myListNfts[index],
            ...data,
            totalCollateral: data.assets ? state.getTotalCollateral(data.assets) : state.myListNfts[index].totalCollateral,
            updatedAt: new Date(),
          }

          set((state) => {
            const newMyListNfts = [...state.myListNfts]
            newMyListNfts[index] = updatedNFT
            return { myListNfts: newMyListNfts }
          })

          return true
        },

        deleteNFT: (id: string) => {
          const state = get()
          const index = state.myListNfts.findIndex((nft) => nft.id === id)
          if (index === -1) return false

          set((state) => ({
            myListNfts: state.myListNfts.filter((nft) => nft.id !== id),
          }))

          return true
        },

        deleteNFTByTokenId: (tokenId: number) => {
          const state = get()
          const index = state.myListNfts.findIndex((nft) => nft.tokenId === tokenId)
          if (index === -1) return false

          set((state) => ({
            myListNfts: state.myListNfts.filter((nft) => nft.tokenId !== tokenId),
          }))

          return true
        },

        toggleListing: (id: string) => {
          const state = get()
          const index = state.myListNfts.findIndex((nft) => nft.id === id)
          if (index === -1) return false

          const updatedNFT = {
            ...state.myListNfts[index],
            isListedForSale: !state.myListNfts[index].isListedForSale,
            updatedAt: new Date(),
          }

          set((state) => {
            const newMyListNfts = [...state.myListNfts]
            newMyListNfts[index] = updatedNFT
            return { myListNfts: newMyListNfts }
          })

          return true
        },

        toggleListingByTokenId: (tokenId: number) => {
          const state = get()
          const index = state.myListNfts.findIndex((nft) => nft.tokenId === tokenId)
          if (index === -1) return false

          const updatedNFT = {
            ...state.myListNfts[index],
            isListedForSale: !state.myListNfts[index].isListedForSale,
            updatedAt: new Date(),
          }

          set((state) => {
            const newMyListNfts = [...state.myListNfts]
            newMyListNfts[index] = updatedNFT
            return { myListNfts: newMyListNfts }
          })

          return true
        },

        // Utilities
        getNFTById: (id: string) => {
          const state = get()
          return state.myListNfts.find((nft) => nft.id === id)
        },

        getTotalCollateral: (assets: Asset[]) => {
          return assets.reduce((sum, asset) => sum + asset.amount, 0)
        },

        generateTokenId: () => {
          const state = get()
          if (state.myListNfts.length === 0) {
            return 0
          }
          const maxTokenId = Math.max(...state.myListNfts.map((nft) => nft.tokenId))
          return maxTokenId + 1
        },

        checkIfNFTExistsByTokenId: (tokenId: number) => {
          const state = get()
          return state.myListNfts.some((nft) => nft.tokenId === tokenId)
        },

        clearNftStoreData: () => {
          set({
            myListNfts: [],
          })
        },
      }),
      {
        name: "decup-nft-store",
      },
    ),
    {
      name: "decup-nft-store",
    },
  ),
)
