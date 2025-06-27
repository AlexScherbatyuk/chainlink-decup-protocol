"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { ArrowUpDown, ArrowUp, ArrowDown } from "lucide-react"
import { useNFTStore, type DeCupNFT } from "@/store/nft-store"

type SortField = "tokenId" | "price" | "totalCollateral" | "chain"
type SortDirection = "asc" | "desc"

export default function OnSaleContent() {
    const { onSaleNfts } = useNFTStore()
    const [sortField, setSortField] = useState<SortField>("tokenId")
    const [sortDirection, setSortDirection] = useState<SortDirection>("asc")

    const handleSort = (field: SortField) => {
        const newDirection = sortField === field && sortDirection === "asc" ? "desc" : "asc"
        setSortField(field)
        setSortDirection(newDirection)
    }

    const getSortedNfts = (): DeCupNFT[] => {
        return [...onSaleNfts].sort((a, b) => {
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

    const sortedNfts = getSortedNfts()

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
                                                        onClick={() => handleSort("tokenId")}
                                                    >
                                                        Token ID {getSortIcon("tokenId")}
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
                                                            <img
                                                                src={nft.icon || "/placeholder.svg"}
                                                                alt={`DeCup NFT ${nft.tokenId}`}
                                                                className="h-10 w-10 rounded-lg object-cover"
                                                            />
                                                        </div>
                                                    </td>
                                                    <td className="p-4 font-mono">#{nft.tokenId}</td>
                                                    <td className="p-4 font-semibold">{nft.price} ETH</td>
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
                                                        <Button size="sm">Buy Now</Button>
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
                                            <Button size="sm" className="w-full">
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
        </main>
    )
} 