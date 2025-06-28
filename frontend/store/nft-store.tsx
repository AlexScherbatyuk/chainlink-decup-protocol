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

export interface DeCupNFT {
  id: string
  tokenId: number
  price: number
  marketPrice?: boolean
  totalCollateral: number
  assets: Asset[]
  chain: "Sepolia" | "AvalancheFuji"
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
  beneficialWallet: string
  isListedForSale?: boolean
}

interface NFTStore {
  // Data
  onSaleNfts: DeCupNFT[]
  myListNfts: DeCupNFT[]
  draftNfts: DeCupNFT[]

  // Actions
  createNFT: (data: NFTFormData) => DeCupNFT
  updateNFT: (id: string, data: Partial<NFTFormData>) => boolean
  deleteNFT: (id: string, tab: "on-sale" | "my-list" | "drafts") => boolean
  toggleListing: (id: string) => boolean
  moveNFTToSale: (id: string) => boolean
  moveNFTToDrafts: (id: string) => boolean

  // Utilities
  getNFTById: (id: string) => DeCupNFT | undefined
  getTotalCollateral: (assets: Asset[]) => number
  generateTokenId: () => number
  initializeTestData: () => void
  clearAllNftData: () => void

  // New functions
  checkIfNFTExists: (id: string) => boolean
  getNFTByTokenId: (tokenId: number) => DeCupNFT | undefined
}

// Test data generation functions
const generateTestAssets = (tokenId: number): Asset[] => {
  const baseAssets = [
    { token: "USDC", baseAmount: 2000 },
    { token: "USDT", baseAmount: 1000 },
    { token: "ETH", baseAmount: 800 },
    { token: "DAI", baseAmount: 500 },
  ]

  return baseAssets
    .map((asset, index) => ({
      id: `${tokenId}-asset-${index}`,
      token: asset.token,
      amount: asset.baseAmount + (tokenId % 1000),
      walletAddress: `0x${Math.random().toString(16).substr(2, 40)}`,
      deposited: false,
    }))
    .slice(0, Math.floor(Math.random() * 3) + 2) // 2-4 assets per NFT
}

const createTestNFT = (id: string, tokenId: number, isListed = false): DeCupNFT => {
  const assets = generateTestAssets(tokenId)
  const totalCollateral = assets.reduce((sum, asset) => sum + asset.amount, 0)

  return {
    id,
    tokenId,
    price: Number((Math.random() * 4 + 0.5).toFixed(2)), // 0.5 - 4.5 ETH
    marketPrice: Math.random() > 0.5, // Random true/false for test data
    totalCollateral,
    assets,
    chain: Math.random() > 0.5 ? "Sepolia" : "AvalancheFuji",
    icon: `/placeholder.svg?height=40&width=40&query=DeCup NFT ${tokenId}`,
    isListedForSale: isListed,
    beneficialWallet: `0x${Math.random().toString(16).substr(2, 40)}`,
    createdAt: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000), // Random date within last 30 days
    updatedAt: new Date(),
  }
}

// Generate initial test data
const generateInitialTestData = () => {
  const onSaleNfts: DeCupNFT[] = [
    createTestNFT("sale-1", 1001, true),
    createTestNFT("sale-2", 1002, true),
    createTestNFT("sale-3", 1003, true),
    createTestNFT("sale-4", 1004, true),
    createTestNFT("sale-5", 1005, true),
    createTestNFT("sale-6", 1006, true),
    createTestNFT("sale-7", 1007, true),
    createTestNFT("sale-8", 1008, true),
  ]

  const myListNfts: DeCupNFT[] = [
    createTestNFT("my-1", 2001, true),
    createTestNFT("my-2", 2002, false),
    createTestNFT("my-3", 2003, true),
    createTestNFT("my-4", 2004, false),
    createTestNFT("my-5", 2005, false),
    createTestNFT("my-6", 2006, true),
  ]

  const draftNfts: DeCupNFT[] = [
    createTestNFT("draft-1", 3001, false),
    createTestNFT("draft-2", 3002, false),
    createTestNFT("draft-3", 3003, false),
  ]

  return { onSaleNfts, myListNfts, draftNfts }
}

// Check if we should load test data
const shouldLoadTestData = () => {
  // Only check environment variable, ignore localStorage for consistency
  return process.env.NEXT_PUBLIC_DEBUG_MODE === "true"
}

// Get initial data based on environment
const getInitialData = () => {
  if (shouldLoadTestData()) {
    console.log("🚀 Loading test data for DeCup NFT store")
    return generateInitialTestData()
  } else {
    console.log("📦 Starting with empty DeCup NFT store")
    return {
      onSaleNfts: [],
      myListNfts: [],
      draftNfts: [],
    }
  }
}

// Custom storage that respects debug mode
const createConditionalStorage = () => {
  return {
    getItem: (name: string) => {
      if (typeof window === "undefined") return null

      // If debug mode is enabled, don't load from storage (always start fresh)
      if (shouldLoadTestData()) {
        return null
      }

      // If debug mode is disabled, load from storage normally
      const item = localStorage.getItem(name)
      return item ? JSON.parse(item) : null
    },
    setItem: (name: string, value: any) => {
      if (typeof window === "undefined") return

      // Only persist if debug mode is disabled
      if (!shouldLoadTestData()) {
        localStorage.setItem(name, JSON.stringify(value))
      }
    },
    removeItem: (name: string) => {
      if (typeof window === "undefined") return
      localStorage.removeItem(name)
    },
  }
}

export const useNFTStore = create<NFTStore>()(
  devtools(
    persist(
      (set, get) => ({
        // Initialize with empty or test data based on environment
        ...getInitialData(),
        // Check if NFT exists in any list
        checkIfNFTExists: (id: string) => {
          const state = get()
          return (
            state.onSaleNfts.some((nft) => nft.id === id) ||
            state.myListNfts.some((nft) => nft.id === id) ||
            state.draftNfts.some((nft) => nft.id === id)
          )
        },

        // Get NFT by tokenId from any list
        getNFTByTokenId: (tokenId: number) => {
          const state = get()
          const allNfts = [...state.onSaleNfts, ...state.myListNfts, ...state.draftNfts]
          return allNfts.find((nft) => nft.tokenId === tokenId)
        },

        // Actions
        createNFT: (data: NFTFormData) => {
          const state = get()

          // Check if NFT with this tokenId already exists
          if (data.tokenId) {
            const existingNFT = state.getNFTByTokenId(data.tokenId)
            if (existingNFT) {
              // Update existing NFT instead of creating new one
              const success = state.updateNFT(existingNFT.id, data)
              if (success) {
                // Return the updated NFT
                return state.getNFTByTokenId(data.tokenId)!
              }
            }
          }

          // Create new NFT if no existing one found
          const tokenId = data.tokenId || state.generateTokenId()
          const newNFT: DeCupNFT = {
            id: `nft-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
            tokenId: tokenId,
            price: data.price,
            marketPrice: data.marketPrice,
            totalCollateral: data.totalCollateral || state.getTotalCollateral(data.assets),
            assets: data.assets,
            chain: data.chain,
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

          const updateInList = (list: DeCupNFT[]): DeCupNFT[] => {
            const index = list.findIndex((nft) => nft.id === id)
            if (index === -1) return list

            const updatedNFT = {
              ...list[index],
              ...data,
              totalCollateral: data.assets ? state.getTotalCollateral(data.assets) : list[index].totalCollateral,
              updatedAt: new Date(),
            }

            const newList = [...list]
            newList[index] = updatedNFT
            return newList
          }

          // Try to update in each list
          const newMyListNfts = updateInList(state.myListNfts)
          const newDraftNfts = updateInList(state.draftNfts)
          const newOnSaleNfts = updateInList(state.onSaleNfts)

          // Check if any list was updated
          const wasUpdated =
            newMyListNfts !== state.myListNfts || newDraftNfts !== state.draftNfts || newOnSaleNfts !== state.onSaleNfts

          if (wasUpdated) {
            set({
              myListNfts: newMyListNfts,
              draftNfts: newDraftNfts,
              onSaleNfts: newOnSaleNfts,
            })
          }

          return wasUpdated
        },

        deleteNFT: (id: string, tab: "on-sale" | "my-list" | "drafts") => {
          const state = get()

          switch (tab) {
            case "on-sale":
              const onSaleIndex = state.onSaleNfts.findIndex((nft) => nft.id === id)
              if (onSaleIndex === -1) return false
              set((state) => ({
                onSaleNfts: state.onSaleNfts.filter((nft) => nft.id !== id),
              }))
              return true

            case "my-list":
              const myListIndex = state.myListNfts.findIndex((nft) => nft.id === id)
              if (myListIndex === -1) return false
              set((state) => ({
                myListNfts: state.myListNfts.filter((nft) => nft.id !== id),
                // Also remove from on-sale if it exists there
                onSaleNfts: state.onSaleNfts.filter((nft) => nft.id !== id),
              }))
              return true

            case "drafts":
              const draftIndex = state.draftNfts.findIndex((nft) => nft.id === id)
              if (draftIndex === -1) return false
              set((state) => ({
                draftNfts: state.draftNfts.filter((nft) => nft.id !== id),
              }))
              return true

            default:
              return false
          }
        },

        toggleListing: (id: string) => {
          const state = get()
          const nftIndex = state.myListNfts.findIndex((nft) => nft.id === id)
          if (nftIndex === -1) return false

          const updatedNFT = {
            ...state.myListNfts[nftIndex],
            isListedForSale: !state.myListNfts[nftIndex].isListedForSale,
            updatedAt: new Date(),
          }

          set((state) => {
            const newMyListNfts = [...state.myListNfts]
            newMyListNfts[nftIndex] = updatedNFT

            let newOnSaleNfts = [...state.onSaleNfts]

            // If listing for sale, add to on-sale list
            if (updatedNFT.isListedForSale) {
              const exists = newOnSaleNfts.find((nft) => nft.id === id)
              if (!exists) {
                newOnSaleNfts = [...newOnSaleNfts, updatedNFT]
              }
            } else {
              // If removing from sale, remove from on-sale list
              newOnSaleNfts = newOnSaleNfts.filter((nft) => nft.id !== id)
            }

            return {
              myListNfts: newMyListNfts,
              onSaleNfts: newOnSaleNfts,
            }
          })

          return true
        },

        moveNFTToSale: (id: string) => {
          const state = get()
          const draftIndex = state.draftNfts.findIndex((nft) => nft.id === id)
          if (draftIndex === -1) return false

          const nft = { ...state.draftNfts[draftIndex], isListedForSale: true, updatedAt: new Date() }

          set((state) => ({
            draftNfts: state.draftNfts.filter((nft) => nft.id !== id),
            myListNfts: [...state.myListNfts, nft],
            onSaleNfts: [...state.onSaleNfts, nft],
          }))

          return true
        },

        moveNFTToDrafts: (id: string) => {
          const state = get()
          const myListIndex = state.myListNfts.findIndex((nft) => nft.id === id)
          if (myListIndex === -1) return false

          const nft = { ...state.myListNfts[myListIndex], isListedForSale: false, updatedAt: new Date() }

          set((state) => ({
            myListNfts: state.myListNfts.filter((nft) => nft.id !== id),
            onSaleNfts: state.onSaleNfts.filter((nft) => nft.id !== id),
            draftNfts: [...state.draftNfts, nft],
          }))

          return true
        },

        // Utilities
        getNFTById: (id: string) => {
          const state = get()
          return [...state.onSaleNfts, ...state.myListNfts, ...state.draftNfts].find((nft) => nft.id === id)
        },

        getTotalCollateral: (assets: Asset[]) => {
          return assets.reduce((sum, asset) => sum + asset.amount, 0)
        },

        generateTokenId: () => {
          const state = get()
          const allNfts = [...state.onSaleNfts, ...state.myListNfts, ...state.draftNfts]
          const maxTokenId = Math.max(...allNfts.map((nft) => nft.tokenId), -1)
          return maxTokenId + 1
        },

        initializeTestData: () => {
          const testData = generateInitialTestData()
          set(testData)
          console.log("🚀 Test data loaded into DeCup NFT store")
        },

        clearAllNftData: () => {
          set({
            onSaleNfts: [],
            myListNfts: [],
            draftNfts: [],
          })
          console.log("🗑️ All data cleared from DeCup NFT store")
        },
      }),
      {
        name: "decup-nft-store",
        storage: createConditionalStorage(),
      },
    ),
    {
      name: "decup-nft-store",
    },
  ),
)

// Initialize store on client side
if (typeof window !== "undefined") {
  // Clear localStorage if debug mode changed
  const currentDebugMode = shouldLoadTestData()
  const storedDebugMode = localStorage.getItem("decup-debug-mode") === "true"

  if (currentDebugMode !== storedDebugMode) {
    console.log("🔄 Debug mode changed, clearing stored data")
    localStorage.removeItem("decup-nft-store")
    localStorage.setItem("decup-debug-mode", currentDebugMode.toString())
  }
  // Add debug helpers to window for development
  ; (window as any).decupStore = {
    loadTestData: () => useNFTStore.getState().initializeTestData(),
    clearData: () => useNFTStore.getState().clearAllNftData(),
    clearStorage: () => {
      localStorage.removeItem("decup-nft-store")
      localStorage.removeItem("decup-debug-mode")
      window.location.reload()
    },
    getDebugMode: () => shouldLoadTestData(),
  }
}
