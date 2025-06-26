"use client"

import { createContext, useContext, useState, type ReactNode } from "react"

export interface Asset {
  id: string
  token: string
  amount: number
  walletAddress: string
}

export interface DeCupNFT {
  id: string
  tokenId: number
  price: number
  totalCollateral: number
  assets: Asset[]
  chain: "Sepolia" | "Fuji"
  icon: string
  isListedForSale?: boolean
  beneficialWallet: string
  createdAt: Date
  updatedAt: Date
}

export interface NFTFormData {
  tokenId?: number
  price: number
  assets: Asset[]
  chain: "Sepolia" | "Fuji"
  beneficialWallet: string
}

interface NFTStoreContext {
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
}

const NFTStoreContext = createContext<NFTStoreContext | undefined>(undefined)

// Test data
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
    totalCollateral,
    assets,
    chain: Math.random() > 0.5 ? "Sepolia" : "Fuji",
    icon: `/placeholder.svg?height=40&width=40&query=DeCup NFT ${tokenId}`,
    isListedForSale: isListed,
    beneficialWallet: `0x${Math.random().toString(16).substr(2, 40)}`,
    createdAt: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000), // Random date within last 30 days
    updatedAt: new Date(),
  }
}

// Initial test data
const initialOnSaleNfts: DeCupNFT[] = [
  createTestNFT("sale-1", 1001, true),
  createTestNFT("sale-2", 1002, true),
  createTestNFT("sale-3", 1003, true),
  createTestNFT("sale-4", 1004, true),
  createTestNFT("sale-5", 1005, true),
  createTestNFT("sale-6", 1006, true),
  createTestNFT("sale-7", 1007, true),
  createTestNFT("sale-8", 1008, true),
]

const initialMyListNfts: DeCupNFT[] = [
  createTestNFT("my-1", 2001, true),
  createTestNFT("my-2", 2002, false),
  createTestNFT("my-3", 2003, true),
  createTestNFT("my-4", 2004, false),
  createTestNFT("my-5", 2005, false),
  createTestNFT("my-6", 2006, true),
]

const initialDraftNfts: DeCupNFT[] = [
  createTestNFT("draft-1", 3001, false),
  createTestNFT("draft-2", 3002, false),
  createTestNFT("draft-3", 3003, false),
]

export function NFTStoreProvider({ children }: { children: ReactNode }) {
  const [onSaleNfts, setOnSaleNfts] = useState<DeCupNFT[]>(initialOnSaleNfts)
  const [myListNfts, setMyListNfts] = useState<DeCupNFT[]>(initialMyListNfts)
  const [draftNfts, setDraftNfts] = useState<DeCupNFT[]>(initialDraftNfts)

  const generateTokenId = (): number => {
    const allNfts = [...onSaleNfts, ...myListNfts, ...draftNfts]
    const maxTokenId = Math.max(...allNfts.map((nft) => nft.tokenId), 0)
    return maxTokenId + 1
  }

  const getTotalCollateral = (assets: Asset[]): number => {
    return assets.reduce((sum, asset) => sum + asset.amount, 0)
  }

  const createNFT = (data: NFTFormData): DeCupNFT => {
    const newNFT: DeCupNFT = {
      id: `nft-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      tokenId: data.tokenId || generateTokenId(),
      price: data.price,
      totalCollateral: getTotalCollateral(data.assets),
      assets: data.assets,
      chain: data.chain,
      icon: `/placeholder.svg?height=40&width=40&query=DeCup NFT ${data.tokenId || generateTokenId()}`,
      isListedForSale: false,
      beneficialWallet: data.beneficialWallet,
      createdAt: new Date(),
      updatedAt: new Date(),
    }

    setMyListNfts((prev) => [...prev, newNFT])
    return newNFT
  }

  const updateNFT = (id: string, data: Partial<NFTFormData>): boolean => {
    const updateInList = (list: DeCupNFT[], setList: (list: DeCupNFT[]) => void): boolean => {
      const index = list.findIndex((nft) => nft.id === id)
      if (index === -1) return false

      const updatedNFT = {
        ...list[index],
        ...data,
        totalCollateral: data.assets ? getTotalCollateral(data.assets) : list[index].totalCollateral,
        updatedAt: new Date(),
      }

      const newList = [...list]
      newList[index] = updatedNFT
      setList(newList)
      return true
    }

    return (
      updateInList(myListNfts, setMyListNfts) ||
      updateInList(draftNfts, setDraftNfts) ||
      updateInList(onSaleNfts, setOnSaleNfts)
    )
  }

  const deleteNFT = (id: string, tab: "on-sale" | "my-list" | "drafts"): boolean => {
    switch (tab) {
      case "on-sale":
        const onSaleIndex = onSaleNfts.findIndex((nft) => nft.id === id)
        if (onSaleIndex === -1) return false
        setOnSaleNfts((prev) => prev.filter((nft) => nft.id !== id))
        return true

      case "my-list":
        const myListIndex = myListNfts.findIndex((nft) => nft.id === id)
        if (myListIndex === -1) return false
        setMyListNfts((prev) => prev.filter((nft) => nft.id !== id))
        return true

      case "drafts":
        const draftIndex = draftNfts.findIndex((nft) => nft.id === id)
        if (draftIndex === -1) return false
        setDraftNfts((prev) => prev.filter((nft) => nft.id !== id))
        return true

      default:
        return false
    }
  }

  const toggleListing = (id: string): boolean => {
    const nftIndex = myListNfts.findIndex((nft) => nft.id === id)
    if (nftIndex === -1) return false

    const updatedNFT = {
      ...myListNfts[nftIndex],
      isListedForSale: !myListNfts[nftIndex].isListedForSale,
      updatedAt: new Date(),
    }

    const newList = [...myListNfts]
    newList[nftIndex] = updatedNFT
    setMyListNfts(newList)

    // If listing for sale, also add to on-sale list
    if (updatedNFT.isListedForSale) {
      setOnSaleNfts((prev) => {
        const exists = prev.find((nft) => nft.id === id)
        if (exists) return prev
        return [...prev, updatedNFT]
      })
    } else {
      // If removing from sale, remove from on-sale list
      setOnSaleNfts((prev) => prev.filter((nft) => nft.id !== id))
    }

    return true
  }

  const moveNFTToSale = (id: string): boolean => {
    const draftIndex = draftNfts.findIndex((nft) => nft.id === id)
    if (draftIndex === -1) return false

    const nft = { ...draftNfts[draftIndex], isListedForSale: true, updatedAt: new Date() }

    setDraftNfts((prev) => prev.filter((nft) => nft.id !== id))
    setMyListNfts((prev) => [...prev, nft])
    setOnSaleNfts((prev) => [...prev, nft])

    return true
  }

  const moveNFTToDrafts = (id: string): boolean => {
    const myListIndex = myListNfts.findIndex((nft) => nft.id === id)
    if (myListIndex === -1) return false

    const nft = { ...myListNfts[myListIndex], isListedForSale: false, updatedAt: new Date() }

    setMyListNfts((prev) => prev.filter((nft) => nft.id !== id))
    setOnSaleNfts((prev) => prev.filter((nft) => nft.id !== id))
    setDraftNfts((prev) => [...prev, nft])

    return true
  }

  const getNFTById = (id: string): DeCupNFT | undefined => {
    return [...onSaleNfts, ...myListNfts, ...draftNfts].find((nft) => nft.id === id)
  }

  const value: NFTStoreContext = {
    // Data
    onSaleNfts,
    myListNfts,
    draftNfts,

    // Actions
    createNFT,
    updateNFT,
    deleteNFT,
    toggleListing,
    moveNFTToSale,
    moveNFTToDrafts,

    // Utilities
    getNFTById,
    getTotalCollateral,
    generateTokenId,
  }

  return <NFTStoreContext.Provider value={value}>{children}</NFTStoreContext.Provider>
}

export function useNFTStore() {
  const context = useContext(NFTStoreContext)
  if (context === undefined) {
    throw new Error("useNFTStore must be used within a NFTStoreProvider")
  }
  return context
}
