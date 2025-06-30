"use client"

import { useEffect, useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { ArrowUpDown, ArrowUp, ArrowDown } from "lucide-react"
import { useNFTSaleStore, type DeCupNFTSale } from "@/store/nft-sale-store"
import { useNFTStore } from "@/store/nft-store"
import { useNFTContext } from "@/contexts/nft-context"
import { getPriceInETH, buy, getSaleOrder, buyCrossSale } from "@/lib/contracts/interactions"
import { AvalancheIcon, EthereumIcon } from "@/components/icons/chain-icons"
import { getContractAddresses } from "@/lib/contracts/addresses"
import { useAccount, useChainId } from "wagmi"
import PendingModal from "../pending-modal"
import { getChainNameById, getChainIdByName } from "@/lib/contracts/chains"

type SortField = "saleId" | "price" | "totalCollateral" | "chain"
type SortDirection = "asc" | "desc"

export default function OnSaleContent() {
    const { deleteNFT, getNFTByTokenId } = useNFTStore()
    const { listedSales, deleteNFTSale } = useNFTSaleStore()
    const { isFetchingSales } = useNFTContext()

    // Get the store instance to access current state
    const nftSaleStore = useNFTSaleStore.getState

    const [sortField, setSortField] = useState<SortField>("saleId")
    const [sortDirection, setSortDirection] = useState<SortDirection>("asc")

    const chainId = useChainId()

    const { address } = useAccount()
    const [isLoading, setIsLoading] = useState(false)


    // Buy NFT
    const handleBuy = async (saleId: number, destinationChain: string) => {
        console.log("handleBuy", saleId)
        const nft = nftSaleStore().listedSales.find(nft => nft.saleId === saleId)
        if (!nft) {
            console.error("NFT not found")
            return
        }
        const amount = nft.totalCollateral

        const destinationChainId = getChainIdByName[destinationChain as keyof typeof getChainIdByName]
        const saleOrderChainId = destinationChainId !== chainId ? destinationChainId : chainId

        console.log("saleOrderChainId", saleOrderChainId)
        console.log("destinationChainId", destinationChainId)
        console.log("chainId", chainId)
        const { success: successCheck, saleOrder } = await getSaleOrder(saleOrderChainId, Number(saleId), getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager)
        if (!successCheck) {
            console.error("Sale not found")
            return
        }
        console.log("saleOrder", saleOrder)
        const { success: successEth, priceInEth } = await getPriceInETH(saleOrder?.priceInUsd, getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager)


        if (nft.destinationChain === getChainNameById[chainId as keyof typeof getChainNameById]) {
            setIsLoading(true)

            console.log("saleOrder", saleOrder)
            try {
                // TODO: Implement actual purchase logic with contract interaction
                console.log("Attempting to buy NFT with saleId:", saleId)
                console.log("chainId", chainId)
                console.log("getContractAddresses", getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager)

                //  const priceInEth = saleOrder?.priceInUsd
                console.log("priceInEth", priceInEth)
                const { success, saleId: saleIdResult } = await buy(BigInt(saleId), getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager, address as `0x${string}`, true, BigInt(priceInEth))
                if (success) {
                    console.log("NFT bought successfully with saleId:", saleIdResult)
                    // Find the NFT sale by saleId first, then delete using internal ID
                    const nftSaleToDelete = nftSaleStore().listedSales.find(sale => sale.saleId === saleId)
                    if (nftSaleToDelete) {
                        console.log("Deleting NFT sale with id:", nftSaleToDelete.id)
                        deleteNFTSale(nftSaleToDelete.id)
                        const nft = getNFTByTokenId(Number(saleOrder?.tokenId))
                        if (nft) {
                            deleteNFT(nft.id)
                        }
                    }
                } else {
                    console.error("Failed to buy NFT")
                }
            } catch (error) {
                console.error("Error buying NFT:", error)
            } finally {
                setIsLoading(false)
            }
        } else {
            setIsLoading(true)

            try {
                // TODO: Implement actual purchase logic with contract interaction
                console.log("Attempting to buy cross chain NFT with saleId:", saleId)
                console.log("chainId", chainId)
                console.log("destinationChainId", destinationChainId)
                console.log("getContractAddresses", getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager)

                //  const priceInEth = saleOrder?.priceInUsd
                console.log("priceInEth", priceInEth)
                const { success, saleId: tokenIdResult } = await buyCrossSale(BigInt(saleId), getContractAddresses[chainId as keyof typeof getContractAddresses].DeCupManager, address as `0x${string}`, true, BigInt(destinationChainId), BigInt(priceInEth))
                if (success) {
                    console.log("Cross chain NFT bought successfully with saleId:", tokenIdResult)
                    // Find the NFT sale by saleId first, then delete using internal ID
                    const nftSaleToDelete = nftSaleStore().listedSales.find(sale => sale.saleId === saleId)
                    if (nftSaleToDelete) {
                        console.log("Deleting NFT sale with id:", nftSaleToDelete.id)
                        deleteNFTSale(nftSaleToDelete.id)
                        const nft = getNFTByTokenId(Number(saleOrder?.tokenId))
                        if (nft) {
                            deleteNFT(nft.id)
                        }
                    }
                } else {
                    console.error("Failed to buy NFT")
                }
            } catch (error) {
                console.error("Error buying NFT:", error)
            } finally {
                setIsLoading(false)
            }
        }
    }

    // Sort NFTs
    const handleSort = (field: SortField) => {
        const newDirection = sortField === field && sortDirection === "asc" ? "desc" : "asc"
        setSortField(field)
        setSortDirection(newDirection)
    }

    // Get sorted NFTs
    const getSortedNfts = (): DeCupNFTSale[] => {
        return [...listedSales].sort((a, b) => {
            let aValue: string | number
            let bValue: string | number

            switch (sortField) {
                case "saleId":
                    aValue = a.saleId
                    bValue = b.saleId
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

    const sortedNfts = getSortedNfts()

    // Note: Sale orders fetching is now handled by NFTProvider context


    return (
        <main className="flex-1 flex justify-center items-center">
            <div className="container px-4 py-8">
                <div className="space-y-6">
                    <div className="flex items-center justify-between">
                        <div>
                            <h1 className="text-3xl font-bold tracking-tight">DeCup NFTs On Sale</h1>
                            <p className="text-muted-foreground">Browse and purchase DeCup NFTs with collateralized assets</p>
                        </div>
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
                                                        onClick={() => handleSort("saleId")}
                                                    >
                                                        Sale ID {getSortIcon("saleId")}
                                                    </Button>
                                                </th>
                                                <th className="text-left p-4 font-medium">
                                                    <Button
                                                        variant="ghost"
                                                        className="h-auto p-0 font-medium"
                                                        onClick={() => handleSort("price")}
                                                    >
                                                        Price {getSortIcon("price")}
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
                                                        Chain {getSortIcon("chain")}
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
                                                            {getChainIcon(nft.chain, "h-10 w-10 rounded-lg object-cover")}
                                                        </div>
                                                    </td>
                                                    <td className="p-4 font-mono">#{nft.saleId}</td>
                                                    <td className="p-4 font-semibold">{nft.price} {nft.chain === "Sepolia" ? "ETH" : "AVAX"}</td>
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
                                                        <Badge variant={nft.destinationChain === "Sepolia" ? "default" : "outline"}>{nft.destinationChain}</Badge>
                                                    </td>
                                                    <td className="p-4">
                                                        <Button size="sm" onClick={() => handleBuy(nft.saleId, nft.destinationChain)}>Buy Now</Button>
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
                                variant={sortField === "saleId" ? "default" : "outline"}
                                size="sm"
                                onClick={() => handleSort("saleId")}
                            >
                                Sale ID {getSortIcon("saleId")}
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
                                        </div>
                                        <div className="flex-1 space-y-2">
                                            <div className="flex items-center justify-between">
                                                <span className="font-mono text-sm">#{nft.saleId}</span>
                                                <Badge variant={nft.chain === "Sepolia" ? "default" : "outline"}>{nft.chain}</Badge>
                                            </div>
                                            <div className="flex items-center justify-between">
                                                <span className="font-semibold">{nft.price} {nft.chain === "Sepolia" ? "ETH" : "AVAX"}</span>
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
                                            <Button size="sm" className="w-full" onClick={() => handleBuy(nft.saleId, nft.destinationChain)}>
                                                Buy Now
                                            </Button>
                                        </div>
                                    </div>
                                </CardContent>
                            </Card>
                        ))}
                    </div>
                </div>
            </div>
            <PendingModal
                isOpen={isLoading}
                onClose={() => { setIsLoading(false) }}
                title="Transaction Pending"
                message="Please wait while your transaction is being processed..."
                transactionType="buy"
            />
        </main>
    )
} 