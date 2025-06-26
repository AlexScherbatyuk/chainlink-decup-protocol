"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { ArrowUpDown, ArrowUp, ArrowDown, Edit, Trash2, ShoppingCart, X, Plus } from "lucide-react"
import NFTModal from "./nft-modal"
import { useNFTStore, type DeCupNFT } from "@/store/nft-store"

type SortField = "tokenId" | "price" | "totalCollateral" | "chain"
type SortDirection = "asc" | "desc"
type TabType = "on-sale" | "my-list" | "drafts"

interface MainContentProps {
  activeTab?: TabType
}

export default function MainContent({ activeTab = "on-sale" }: MainContentProps) {
  const { onSaleNfts, myListNfts, draftNfts, deleteNFT, toggleListing } = useNFTStore()

  const [sortField, setSortField] = useState<SortField>("tokenId")
  const [sortDirection, setSortDirection] = useState<SortDirection>("asc")
  const [isModalOpen, setIsModalOpen] = useState(false)
  const [modalMode, setModalMode] = useState<"create" | "edit">("create")
  const [editingNftId, setEditingNftId] = useState<string | undefined>()

  const getCurrentNfts = (): DeCupNFT[] => {
    switch (activeTab) {
      case "on-sale":
        return onSaleNfts
      case "my-list":
        return myListNfts
      case "drafts":
        return draftNfts
      default:
        return []
    }
  }

  const currentNfts = getCurrentNfts()

  const handleSort = (field: SortField) => {
    const newDirection = sortField === field && sortDirection === "asc" ? "desc" : "asc"
    setSortField(field)
    setSortDirection(newDirection)
  }

  const getSortedNfts = (): DeCupNFT[] => {
    return [...currentNfts].sort((a, b) => {
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

  const handleToggleListing = (nftId: string) => {
    toggleListing(nftId)
  }

  const handleEdit = (nftId: string) => {
    setModalMode("edit")
    setEditingNftId(nftId)
    setIsModalOpen(true)
  }

  const handleDelete = (nftId: string) => {
    if (confirm("Are you sure you want to delete this NFT?")) {
      deleteNFT(nftId, activeTab)
    }
  }

  const handleCreate = () => {
    setModalMode("create")
    setEditingNftId(undefined)
    setIsModalOpen(true)
  }

  const getTabTitle = () => {
    switch (activeTab) {
      case "on-sale":
        return "DeCup NFTs On Sale"
      case "my-list":
        return "My DeCup NFTs"
      case "drafts":
        return "Draft NFTs"
      default:
        return "DeCup NFTs"
    }
  }

  const getTabDescription = () => {
    switch (activeTab) {
      case "on-sale":
        return "Browse and purchase DeCup NFTs with collateralized assets"
      case "my-list":
        return "Manage your DeCup NFT collection"
      case "drafts":
        return "Your draft NFTs waiting to be minted"
      default:
        return ""
    }
  }

  const sortedNfts = getSortedNfts()

  if (activeTab === "drafts" && sortedNfts.length === 0) {
    return (
      <main className="flex-1">
        <div className="container px-4 py-8">
          <div className="text-center py-12">
            <h1 className="text-3xl font-bold tracking-tight">Draft NFTs</h1>
            <p className="text-muted-foreground mt-2">Your draft NFTs will appear here</p>
          </div>
        </div>
      </main>
    )
  }

  return (
    <main className="flex-1 flex justify-center items-center">
      <div className="container px-4 py-8">
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold tracking-tight">{getTabTitle()}</h1>
              <p className="text-muted-foreground">{getTabDescription()}</p>
            </div>
            {(activeTab === "my-list" || activeTab === "drafts") && (
              <Button onClick={() => handleCreate()} className="flex items-center space-x-2">
                <Plus className="h-4 w-4" />
                <span>Create</span>
              </Button>
            )}
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
                              {activeTab === "my-list" && nft.isListedForSale && (
                                <div className="absolute -top-1 -right-1 h-3 w-3 bg-green-500 rounded-full border-2 border-white"></div>
                              )}
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
                            {activeTab === "on-sale" ? (
                              <Button size="sm">Buy Now</Button>
                            ) : (
                              <div className="flex gap-2">
                                {activeTab === "my-list" && (
                                  <Button
                                    size="sm"
                                    variant={nft.isListedForSale ? "destructive" : "default"}
                                    className="min-w-[80px]"
                                    onClick={() => handleToggleListing(nft.id)}
                                  >
                                    {nft.isListedForSale ? (
                                      <>
                                        <X className="h-3 w-3 mr-1" />
                                        Remove
                                      </>
                                    ) : (
                                      <>
                                        <ShoppingCart className="h-3 w-3 mr-1" />
                                        List
                                      </>
                                    )}
                                  </Button>
                                )}
                                <Button size="sm" variant="outline" onClick={() => handleEdit(nft.id)}>
                                  <Edit className="h-3 w-3" />
                                </Button>
                                <Button size="sm" variant="outline" onClick={() => handleDelete(nft.id)}>
                                  <Trash2 className="h-3 w-3" />
                                </Button>
                              </div>
                            )}
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
                      {activeTab === "my-list" && nft.isListedForSale && (
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
                      {activeTab === "on-sale" ? (
                        <Button size="sm" className="w-full">
                          Buy Now
                        </Button>
                      ) : (
                        <div className="flex gap-2">
                          {activeTab === "my-list" && (
                            <Button
                              size="sm"
                              variant={nft.isListedForSale ? "destructive" : "default"}
                              className="min-w-[80px] flex-1"
                              onClick={() => handleToggleListing(nft.id)}
                            >
                              {nft.isListedForSale ? "Remove" : "List"}
                            </Button>
                          )}
                          <Button size="sm" variant="outline" onClick={() => handleEdit(nft.id)}>
                            <Edit className="h-3 w-3" />
                          </Button>
                          <Button size="sm" variant="outline" onClick={() => handleDelete(nft.id)}>
                            <Trash2 className="h-3 w-3" />
                          </Button>
                        </div>
                      )}
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </div>

      <NFTModal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} mode={modalMode} nftId={editingNftId} />
    </main>
  )
}
