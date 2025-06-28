"use client"

import { useEffect, useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { ArrowUpDown, ArrowUp, ArrowDown, Edit, Trash2, ShoppingCart, X, Plus } from "lucide-react"
import NFTModal from "../nft-modal"
import ListModal from "../list-modal"
import DeleteModal from "../delete-modal"
import { useNFTStore, type DeCupNFT } from "@/store/nft-store"
import { useNFTSaleStore } from "@/store/nft-sale-store"
import { getMyDeCupNfts, getTokenAssetsList, getTokenPriceInUsd } from "@/lib/contracts/interactions"
import { getContractAddresses, getTokenAddresses, getTokenSymbols } from "@/lib/contracts/addresses"
import { useAccount, useChainId, useSwitchChain } from 'wagmi'
import { getChainNameById } from "@/lib/contracts/chains"


type SortField = "tokenId" | "price" | "totalCollateral" | "chain"
type SortDirection = "asc" | "desc"

export default function MyListContent() {
    const { myListNfts, clearAllData, createNFT, deleteNFT, toggleListing, getNFTById } = useNFTStore()
    const { createNFTSale, deleteNFTSale, getNFTSaleBySaleId } = useNFTSaleStore()

    const chainId = useChainId()
    const { address, isConnected } = useAccount()

    const [sortField, setSortField] = useState<SortField>("tokenId")
    const [sortDirection, setSortDirection] = useState<SortDirection>("asc")
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [modalMode, setModalMode] = useState<"create" | "edit">("create")
    const [editingNftId, setEditingNftId] = useState<string | undefined>()
    const [isLoading, setIsLoading] = useState(false)

    // List/Unlist confirmation modal state
    const [isListingDialogOpen, setIsListingDialogOpen] = useState(false)
    const [nftToToggleListing, setNftToToggleListing] = useState<DeCupNFT | null>(null)

    // Delete confirmation modal state
    const [isDeleteDialogOpen, setIsDeleteDialogOpen] = useState(false)
    const [nftToDelete, setNftToDelete] = useState<DeCupNFT | null>(null)

    const handleSort = (field: SortField) => {
        const newDirection = sortField === field && sortDirection === "asc" ? "desc" : "asc"
        setSortField(field)
        setSortDirection(newDirection)
    }

    const getSortedNfts = (): DeCupNFT[] => {
        return [...myListNfts].sort((a, b) => {
            let aValue: string | number
            let bValue: string | number

            switch (sortField) {
                case "tokenId":
                    aValue = a.tokenId
                    bValue = b.tokenId
                    break
                case "price":
                    aValue = a.price
                    bValue = b.price
                    break
                case "totalCollateral":
                    aValue = a.totalCollateral
                    bValue = b.totalCollateral
                    break
                case "chain":
                    aValue = a.chain
                    bValue = b.chain
                    break
                default:
                    return 0
            }

            if (typeof aValue === "string" && typeof bValue === "string") {
                return sortDirection === "asc" ? aValue.localeCompare(bValue) : bValue.localeCompare(aValue)
            }

            if (typeof aValue === "number" && typeof bValue === "number") {
                return sortDirection === "asc" ? aValue - bValue : bValue - aValue
            }

            return 0
        })
    }

    const getSortIcon = (field: SortField) => {
        if (sortField !== field) {
            return <ArrowUpDown className="h-4 w-4" />
        }
        return sortDirection === "asc" ? <ArrowUp className="h-4 w-4" /> : <ArrowDown className="h-4 w-4" />
    }

    const handleToggleListingClick = (nft: DeCupNFT) => {
        setNftToToggleListing(nft)
        setIsListingDialogOpen(true)
    }

    const handleListingConfirm = (selectedChain?: "Sepolia" | "AvalancheFuji") => {
        if (nftToToggleListing) {
            const isCurrentlyListed = nftToToggleListing.isListedForSale

            // If we're listing (not currently listed) and a chain is provided, update the chain first
            if (!isCurrentlyListed && selectedChain) {
                // Update the NFT with the selected chain
                // Note: You might need to add updateNFT method to your store if it doesn't exist
                // updateNFT(nftToToggleListing.id, { chain: selectedChain })
            }

            // Toggle the listing status
            toggleListing(nftToToggleListing.id)

            // Handle sale store logic based on the previous state
            if (isCurrentlyListed) {
                // NFT was listed, now being unlisted - delete from sale store
                const existingSale = getNFTSaleBySaleId(nftToToggleListing.tokenId)
                if (existingSale) {
                    deleteNFTSale(existingSale.id)
                }
            } else {
                // NFT was not listed, now being listed - create sale in sale store
                createNFTSale({
                    saleId: nftToToggleListing.tokenId,
                    price: nftToToggleListing.price,
                    assets: nftToToggleListing.assets,
                    chain: selectedChain || nftToToggleListing.chain,
                    beneficialWallet: nftToToggleListing.beneficialWallet
                })
            }

            setNftToToggleListing(null)
            setIsListingDialogOpen(false)
        }
    }

    const handleListingCancel = () => {
        setNftToToggleListing(null)
        setIsListingDialogOpen(false)
    }

    const handleEdit = (nftId: string) => {
        setModalMode("edit")
        setEditingNftId(nftId)
        setIsModalOpen(true)
    }

    const handleDeleteClick = (nft: DeCupNFT) => {
        setNftToDelete(nft)
        setIsDeleteDialogOpen(true)
    }

    const handleDeleteConfirm = () => {
        if (nftToDelete) {
            deleteNFT(nftToDelete.id, "my-list")
            setNftToDelete(null)
            setIsDeleteDialogOpen(false)
        }
    }

    const handleDeleteCancel = () => {
        setNftToDelete(null)
        setIsDeleteDialogOpen(false)
    }

    const handleCreate = () => {
        setModalMode("create")
        setEditingNftId(undefined)
        setIsModalOpen(true)
    }

    const sortedNfts = getSortedNfts()

    const fetchMyDeCupNfts = async () => {
        try {
            const { success, nfts } = await getMyDeCupNfts(getContractAddresses[chainId as keyof typeof getContractAddresses].DeCup, address as `0x${string}`)

            if (success && nfts.length > 0) {
                console.log(`Found ${nfts.length} NFTs:`, nfts)

                for (const tokenId of nfts) {
                    let tokenSymbols: string[] = []
                    let totalCollateral = await getTokenPriceInUsd(tokenId, getContractAddresses[chainId as keyof typeof getContractAddresses].DeCup)
                    const { success, tokenAddresses } = await getTokenAssetsList(tokenId, getContractAddresses[chainId as keyof typeof getContractAddresses].DeCup)
                    if (success) {
                        for (const tokenAddress of tokenAddresses) {
                            const chainTokens = getTokenSymbols[chainId as keyof typeof getTokenSymbols];
                            const symbol = chainTokens?.[tokenAddress as keyof typeof chainTokens];
                            tokenSymbols.push(symbol);
                        }
                    }
                    console.log(tokenId, " ", totalCollateral, "[", tokenSymbols, "] ", getChainNameById[chainId as keyof typeof getChainNameById])
                    createNFT({
                        tokenId: Number(tokenId),
                        price: Number(BigInt(totalCollateral.price) * BigInt(1e2) / BigInt(1e8)),
                        assets: tokenSymbols.map((symbol, index) => ({
                            id: index.toString(),
                            token: symbol,
                            amount: 1,
                            walletAddress: address as `0x${string}`,
                            deposited: true
                        })),
                        chain: getChainNameById[chainId as keyof typeof getChainNameById] as "Sepolia" | "AvalancheFuji",
                        beneficialWallet: address as `0x${string}`
                    })
                }
            } else {
                console.log('No NFTs found or fetch failed')
            }
        } catch (error) {
            console.error('Error fetching NFTs:', error)
        } finally {
            // setIsLoading(false)
        }
    }

    useEffect(() => {
        if (isConnected && address) {
            if (myListNfts.length === 0) {
                fetchMyDeCupNfts()
            }
        } else {
            clearAllData()
        }
    }, [chainId, address, isConnected])

    return (
        <main className="flex-1 flex justify-center items-center">
            <div className="container px-4 py-8">
                <div className="space-y-6">
                    <div className="flex items-center justify-between">
                        <div>
                            <h1 className="text-3xl font-bold tracking-tight">My DeCup NFTs</h1>
                            <p className="text-muted-foreground">Manage your DeCup NFT collection</p>
                        </div>
                        <Button onClick={() => handleCreate()} className="flex items-center space-x-2">
                            <Plus className="h-4 w-4" />
                            <span>Create</span>
                        </Button>
                    </div>

                    {/* Desktop Table View */}
                    <div className="hidden md:block">
                        <Card>
                            <CardContent className="p-0">
                                <div className="overflow-x-auto">
                                    <table className="w-full">
                                        <thead>
                                            <tr className="border-b">
                                                <th className="text-left p-4 font-medium">NFT</th>
                                                <th className="text-left p-4 font-medium">
                                                    <Button
                                                        variant="ghost"
                                                        className="h-auto p-0 font-medium"
                                                        onClick={() => handleSort("tokenId")}
                                                    >
                                                        Token ID {getSortIcon("tokenId")}
                                                    </Button>
                                                </th>

                                                <th className="text-left p-4 font-medium">
                                                    <Button
                                                        variant="ghost"
                                                        className="h-auto p-0 font-medium"
                                                        onClick={() => handleSort("totalCollateral")}
                                                    >
                                                        Total Collateral {getSortIcon("totalCollateral")}
                                                    </Button>
                                                </th>
                                                <th className="text-left p-4 font-medium">Assets</th>
                                                <th className="text-left p-4 font-medium">
                                                    <Button
                                                        variant="ghost"
                                                        className="h-auto p-0 font-medium"
                                                        onClick={() => handleSort("chain")}
                                                    >
                                                        Minted on {getSortIcon("chain")}
                                                    </Button>
                                                </th>
                                                <th className="text-left p-4 font-medium">Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {sortedNfts.map((nft) => (
                                                <tr key={nft.id} className="border-b hover:bg-muted/50">
                                                    <td className="p-4">
                                                        <div className="relative">
                                                            <img
                                                                src={nft.icon || "/placeholder.svg"}
                                                                alt={`DeCup NFT ${nft.tokenId}`}
                                                                className="h-10 w-10 rounded-lg object-cover"
                                                            />
                                                            {nft.isListedForSale && (
                                                                <div className="absolute -top-1 -right-1 h-3 w-3 bg-green-500 rounded-full border-2 border-white"></div>
                                                            )}
                                                        </div>
                                                    </td>
                                                    <td className="p-4 font-mono">#{nft.tokenId}</td>

                                                    <td className="p-4">${nft.totalCollateral.toLocaleString()}</td>
                                                    <td className="p-4">
                                                        <div className="flex flex-wrap gap-1">
                                                            {nft.assets.slice(0, 3).map((asset) => (
                                                                <Badge key={asset.id} variant="secondary" className="text-xs">
                                                                    {asset.token} {asset.amount.toLocaleString()}
                                                                </Badge>
                                                            ))}
                                                            {nft.assets.length > 3 && (
                                                                <Badge variant="outline" className="text-xs">
                                                                    +{nft.assets.length - 3} more
                                                                </Badge>
                                                            )}
                                                        </div>
                                                    </td>
                                                    <td className="p-4">
                                                        <Badge variant={nft.chain === "Sepolia" ? "default" : "outline"}>{nft.chain}</Badge>
                                                    </td>
                                                    <td className="p-4">
                                                        <div className="flex gap-2">
                                                            <Button
                                                                size="sm"
                                                                variant={nft.isListedForSale ? "destructive" : "default"}
                                                                className="min-w-[80px]"
                                                                onClick={() => handleToggleListingClick(nft)}
                                                            >
                                                                {nft.isListedForSale ? (
                                                                    <>
                                                                        <X className="h-3 w-3 mr-1" />
                                                                        Unlist
                                                                    </>
                                                                ) : (
                                                                    <>
                                                                        <ShoppingCart className="h-3 w-3 mr-1" />
                                                                        List
                                                                    </>
                                                                )}
                                                            </Button>
                                                            <Button size="sm" variant="outline" onClick={() => handleEdit(nft.id)}>
                                                                <Edit className="h-3 w-3" />
                                                            </Button>
                                                            <Button size="sm" variant="outline" onClick={() => handleDeleteClick(nft)}>
                                                                <Trash2 className="h-3 w-3" />
                                                            </Button>
                                                        </div>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </CardContent>
                        </Card>
                    </div>

                    {/* Mobile Card View */}
                    <div className="md:hidden space-y-4">
                        <div className="flex gap-2 overflow-x-auto pb-2">
                            <Button
                                variant={sortField === "tokenId" ? "default" : "outline"}
                                size="sm"
                                onClick={() => handleSort("tokenId")}
                            >
                                Token ID {getSortIcon("tokenId")}
                            </Button>
                            <Button
                                variant={sortField === "price" ? "default" : "outline"}
                                size="sm"
                                onClick={() => handleSort("price")}
                            >
                                Price {getSortIcon("price")}
                            </Button>
                            <Button
                                variant={sortField === "totalCollateral" ? "default" : "outline"}
                                size="sm"
                                onClick={() => handleSort("totalCollateral")}
                            >
                                TLC {getSortIcon("totalCollateral")}
                            </Button>
                            <Button
                                variant={sortField === "chain" ? "default" : "outline"}
                                size="sm"
                                onClick={() => handleSort("chain")}
                            >
                                Chain {getSortIcon("chain")}
                            </Button>
                        </div>

                        {sortedNfts.map((nft) => (
                            <Card key={nft.id}>
                                <CardContent className="p-4">
                                    <div className="flex items-start gap-4">
                                        <div className="relative">
                                            <img
                                                src={nft.icon || "/placeholder.svg"}
                                                alt={`DeCup NFT ${nft.tokenId}`}
                                                className="h-16 w-16 rounded-lg object-cover flex-shrink-0"
                                            />
                                            {nft.isListedForSale && (
                                                <div className="absolute -top-1 -right-1 h-4 w-4 bg-green-500 rounded-full border-2 border-white"></div>
                                            )}
                                        </div>
                                        <div className="flex-1 space-y-2">
                                            <div className="flex items-center justify-between">
                                                <span className="font-mono text-sm">#{nft.tokenId}</span>
                                                <Badge variant={nft.chain === "Sepolia" ? "default" : "outline"}>{nft.chain}</Badge>
                                            </div>
                                            <div className="flex items-center justify-between">
                                                <span className="font-semibold">{nft.price} ETH</span>
                                                <span className="text-sm text-muted-foreground">
                                                    TLC: ${nft.totalCollateral.toLocaleString()}
                                                </span>
                                            </div>
                                            <div className="flex flex-wrap gap-1">
                                                {nft.assets.slice(0, 3).map((asset) => (
                                                    <Badge key={asset.id} variant="secondary" className="text-xs">
                                                        {asset.token} {asset.amount.toLocaleString()}
                                                    </Badge>
                                                ))}
                                                {nft.assets.length > 3 && (
                                                    <Badge variant="outline" className="text-xs">
                                                        +{nft.assets.length - 3} more
                                                    </Badge>
                                                )}
                                            </div>
                                            <div className="flex gap-2">
                                                <Button
                                                    size="sm"
                                                    variant={nft.isListedForSale ? "destructive" : "default"}
                                                    className="min-w-[80px] flex-1"
                                                    onClick={() => handleToggleListingClick(nft)}
                                                >
                                                    {nft.isListedForSale ? "Unlist" : "List"}
                                                </Button>
                                                <Button size="sm" variant="outline" onClick={() => handleEdit(nft.id)}>
                                                    <Edit className="h-3 w-3" />
                                                </Button>
                                                <Button size="sm" variant="outline" onClick={() => handleDeleteClick(nft)}>
                                                    <Trash2 className="h-3 w-3" />
                                                </Button>
                                            </div>
                                        </div>
                                    </div>
                                </CardContent>
                            </Card>
                        ))}
                    </div>
                </div>
            </div>

            <NFTModal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} mode={modalMode} nftId={editingNftId} />

            {/* List/Unlist Confirmation Modal */}
            <ListModal
                isOpen={isListingDialogOpen}
                onClose={handleListingCancel}
                nft={nftToToggleListing}
                onConfirm={handleListingConfirm}
            />

            {/* Delete Confirmation Modal */}
            <DeleteModal
                isOpen={isDeleteDialogOpen}
                onClose={handleDeleteCancel}
                nft={nftToDelete}
                onConfirm={handleDeleteConfirm}
            />
        </main>
    )
} 