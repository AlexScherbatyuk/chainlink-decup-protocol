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
import { useNFTContext } from "@/contexts/nft-context"
import {
    cancelCrossSale, createCrossSale, createSale, cancelSale, burn,
    getTokenPriceInUsd
} from "@/lib/contracts/interactions"
import { AvalancheIcon, EthereumIcon } from "@/components/icons/chain-icons"
import { getContractAddresses, getTokenAddresses, getTokenSymbols } from "@/lib/contracts/addresses"
import { useAccount, useChainId, useSwitchChain } from 'wagmi'
import { getChainNameById, getChainIdByName } from "@/lib/contracts/chains"
import PendingModal from "../pending-modal"


type SortField = "tokenId" | "price" | "totalCollateral" | "chain" | "destinationChain" | "isListedForSale"
type SortDirection = "asc" | "desc"

export default function MyListContent() {
    const { myListNfts, deleteNFT, deleteNFTByTokenId, toggleListing } = useNFTStore()
    const { createNFTSale, deleteNFTSale, deleteNFTSaleByTokenId, getNFTSaleBySaleId, getNFTSaleByChainIdTokenId } = useNFTSaleStore()
    const { isFetching } = useNFTContext()

    const chainId = useChainId()
    const { address } = useAccount()

    const [sortField, setSortField] = useState<SortField>("tokenId")
    const [sortDirection, setSortDirection] = useState<SortDirection>("asc")
    const [isModalOpen, setIsModalOpen] = useState(false)
    const [modalMode, setModalMode] = useState<"create" | "edit">("create")
    const [editingNftId, setEditingNftId] = useState<string | undefined>()
    const [isLoading, setIsLoading] = useState(false)
    const [transactionType, setTransactionType] = useState<"buy" | "burn" | "list" | "unlist">("burn")

    // List/Unlist confirmation modal state
    const [isListingDialogOpen, setIsListingDialogOpen] = useState(false)
    const [nftToToggleListing, setNftToToggleListing] = useState<DeCupNFT | null>(null)

    // Delete confirmation modal state
    const [isDeleteDialogOpen, setIsDeleteDialogOpen] = useState(false)
    const [nftToDelete, setNftToDelete] = useState<DeCupNFT | null>(null)

    // Handle sort
    const handleSort = (field: SortField) => {
        const newDirection = sortField === field && sortDirection === "asc" ? "desc" : "asc"
        setSortField(field)
        setSortDirection(newDirection)
    }

    // Get sorted NFTs
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
                case "destinationChain":
                    aValue = a.destinationChain
                    bValue = b.destinationChain
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

    // Get sort icon
    const getSortIcon = (field: SortField) => {
        if (sortField !== field) {
            return <ArrowUpDown className="h-4 w-4" />
        }
        return sortDirection === "asc" ? <ArrowUp className="h-4 w-4" /> : <ArrowDown className="h-4 w-4" />
    }

    // Get chain icon
    const getChainIcon = (chain: string, className: string = "h-10 w-10 rounded-lg") => {
        switch (chain) {
            case "AvalancheFuji":
                return <AvalancheIcon className={className} />
            case "Sepolia":
                return <EthereumIcon className={className} />
            default:
                return <div className={`${className} bg-gray-200 rounded-lg`} />
        }
    }

    // Open listing cancel modal, and toggle listing status
    const handleToggleListingClick = (nft: DeCupNFT) => {
        setIsListingDialogOpen(true)
        setNftToToggleListing(nft)
    }

    // Handle listing confirm
    const handleListingConfirm = async (selectedChain?: "Sepolia" | "AvalancheFuji") => {

        //TODO: remove this
        console.log("handleListingConfirm")
        console.log("nftToToggleListing", nftToToggleListing)
        console.log("selectedChain", selectedChain)
        console.log("chainId", chainId)
        console.log("nftToToggleListing.chain", nftToToggleListing?.chain)
        console.log("nftToToggleListing.isListedForSale", nftToToggleListing?.isListedForSale)
        console.log("nftToToggleListing.tokenId", nftToToggleListing?.tokenId)
        console.log("nftToToggleListing.beneficialWallet", nftToToggleListing?.beneficialWallet)
        console.log("nftToToggleListing.price", nftToToggleListing?.price)
        console.log("nftToToggleListing.assets", nftToToggleListing?.assets)

        if (nftToToggleListing) {
            console.log("nftToToggleListing")
            const isCurrentlyListed = nftToToggleListing.isListedForSale

            // Toggle the listing status
            toggleListing(nftToToggleListing.id)

            // Handle sale store logic based on the previous state
            if (isCurrentlyListed) {
                setTransactionType("unlist")
                setIsLoading(true)
                try {
                    console.log("isCurrentlyListed - unlisting NFT")
                    // NFT was listed, now being unlisted - delete from sale store
                    console.log("chainId:", nftToToggleListing.chain)
                    console.log("tokenId:", nftToToggleListing.tokenId)

                    const destinationChainId = getChainIdByName[nftToToggleListing.destinationChain]
                    let success

                    if (destinationChainId !== chainId) {
                        // TODO: change to cancelCrossSale
                        ({ success, } = await cancelCrossSale(BigInt(nftToToggleListing.tokenId), getContractAddresses[destinationChainId as keyof typeof getContractAddresses].DeCupManager))
                    } else {
                        ({ success, } = await cancelSale(BigInt(nftToToggleListing.tokenId), getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager))
                    }
                    if (success) {
                        deleteNFTSaleByTokenId(nftToToggleListing.tokenId)
                    }
                } catch (error) {
                    console.error('Error canceling sale:', error)
                } finally {
                    setIsLoading(false)
                }
            } else {
                // NFT was not listed, now being listed - create sale in sale store
                if (!selectedChain) {
                    console.error("No chain selected for listing")
                    return
                }

                setTransactionType("list")
                setIsLoading(true)
                try {
                    console.log("Creating sale for NFT:", nftToToggleListing.tokenId)
                    console.log("Creating sale for NFT on chain:", selectedChain)
                    const destinationChainId = getChainIdByName[selectedChain]
                    console.log("Creating sale for destinationChainId:", destinationChainId)
                    console.log("beneficialWallet", nftToToggleListing.beneficialWallet)
                    console.log("chainId", chainId)
                    console.log("nftToToggleListing.price", nftToToggleListing.price)

                    const { success: successGetTokenPriceInUsd, price: tokenPriceInUsd } = await getTokenPriceInUsd(BigInt(nftToToggleListing.tokenId), getContractAddresses[chainId as keyof typeof getContractAddresses].DeCup)

                    console.log("tokenPriceInUsd", tokenPriceInUsd)
                    let success, tokenId, saleId

                    if (destinationChainId !== chainId) {
                        // Cross-chain sale
                        ({ success, tokenId } = await createCrossSale(BigInt(nftToToggleListing.tokenId), address as `0x${string}`, getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager, chainId, destinationChainId, tokenPriceInUsd))
                    } else {
                        // Same-chain sale
                        ({ success, saleId } = await createSale(BigInt(nftToToggleListing.tokenId), address as `0x${string}`, getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager, chainId, chainId))

                        if (success) {
                            createNFTSale({
                                saleId: Number(saleId),
                                price: nftToToggleListing.price,
                                assets: nftToToggleListing.assets,
                                chain: nftToToggleListing.chain,
                                destinationChain: selectedChain,
                                beneficialWallet: address as `0x${string}`
                            })
                        }
                    }
                } catch (error) {
                    console.error('Error creating sale:', error)
                } finally {
                    setIsLoading(false)
                }
            }

            setNftToToggleListing(null)
            setIsListingDialogOpen(false)
        }
    }

    // Open listing cancel modal
    const handleListingCancel = () => {
        setNftToToggleListing(null)
        setIsListingDialogOpen(false)
    }

    // Open edit NFT modal
    const handleEdit = (nftId: string) => {
        setModalMode("edit")
        setEditingNftId(nftId)
        setIsModalOpen(true)
    }

    // Open delete NFT modal
    const handleDeleteClick = (nft: DeCupNFT) => {
        setNftToDelete(nft)
        setIsDeleteDialogOpen(true)
    }

    // Handle delete NFT
    const handleDeleteConfirm = async () => {
        if (nftToDelete) {
            setIsLoading(true)
            try {
                const { success, tokenId } = await burn(BigInt(nftToDelete.tokenId), getContractAddresses[chainId as keyof typeof getContractAddresses].DeCup, address as `0x${string}`)
                if (success) {
                    deleteNFTByTokenId(nftToDelete.tokenId)
                    setNftToDelete(null)
                    setIsDeleteDialogOpen(false)
                }
            } catch (error) {
                console.error('Error burning NFT:', error)
            } finally {
                setIsLoading(false)
            }
        }
    }

    // Open delete NFT modal
    const handleDeleteCancel = () => {
        setNftToDelete(null)
        setIsDeleteDialogOpen(false)
    }

    // Open create NFT modal
    const handleCreate = () => {
        setModalMode("create")
        setEditingNftId(undefined)
        setIsModalOpen(true)
    }

    // Get sorted NFTs
    const sortedNfts = getSortedNfts()

    // Note: NFT fetching is now handled by NFTProvider context

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
                                                <th className="text-left p-4 font-medium">
                                                    <Button
                                                        variant="ghost"
                                                        className="h-auto p-0 font-medium"
                                                        onClick={() => handleSort("destinationChain")}
                                                    >
                                                        Sale on {getSortIcon("chain")}
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
                                                            {getChainIcon(nft.destinationChain, "h-10 w-10 rounded-lg object-cover")}
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
                                                        <Badge variant={nft.destinationChain === "Sepolia" ? "default" : "outline"}>{nft.destinationChain}</Badge>
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
                                                            <Button size="sm" variant="outline" onClick={() => handleEdit(nft.id)} disabled={nft.isListedForSale} title={nft.isListedForSale ? "Cannot edit listed NFT" : "Edit DeCup NFT"}>
                                                                <Edit className="h-3 w-3" />
                                                            </Button>
                                                            <Button size="sm" variant="outline" onClick={() => handleDeleteClick(nft)} disabled={nft.isListedForSale} title={nft.isListedForSale ? "Cannot delete listed NFT" : "Burn DeCup NFT"}>
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
                                            {getChainIcon(nft.chain, "h-16 w-16 rounded-lg object-cover flex-shrink-0")}
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
                onConfirm={(selectedChain) => handleListingConfirm(selectedChain)}
            />

            {/* Delete Confirmation Modal */}
            <DeleteModal
                isOpen={isDeleteDialogOpen}
                onClose={handleDeleteCancel}
                nft={nftToDelete}
                onConfirm={handleDeleteConfirm}
            />
            <PendingModal
                isOpen={isLoading}
                onClose={() => { setIsLoading(false) }}
                title="Transaction Pending"
                message="Please wait while your transaction is being processed..."
                transactionType={transactionType}
            />
        </main>
    )
} 