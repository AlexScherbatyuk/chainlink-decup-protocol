"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
} from "@/components/ui/dialog"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Label } from "@/components/ui/label"
import { type DeCupNFT } from "@/store/nft-store"

const AVAILABLE_CHAINS = [
    { value: "Sepolia", label: "Sepolia Testnet" },
    { value: "AvalancheFuji", label: "Avalanche Fuji" },
]

interface ListModalProps {
    isOpen: boolean
    onClose: () => void
    nft: DeCupNFT | null
    onConfirm: (selectedChain?: "Sepolia" | "AvalancheFuji") => void
}

export default function ListModal({ isOpen, onClose, nft, onConfirm }: ListModalProps) {
    const [selectedChain, setSelectedChain] = useState<"Sepolia" | "AvalancheFuji">(
        nft?.chain as "Sepolia" | "AvalancheFuji" || "Sepolia"
    )

    const handleConfirm = () => {
        onConfirm(nft?.isListedForSale ? undefined : selectedChain)
    }

    const handleCancel = () => {
        onClose()
    }

    if (!nft) return null

    return (
        <Dialog open={isOpen} onOpenChange={onClose}>
            <DialogContent className="sm:max-w-md">
                <DialogHeader>
                    <DialogTitle>{nft.isListedForSale ? "Remove from Sale" : "List for Sale"}</DialogTitle>
                    <DialogDescription>
                        {nft.isListedForSale
                            ? `Are you sure you want to remove NFT #${nft.tokenId} from the marketplace?`
                            : `List NFT #${nft.tokenId} for sale on the marketplace.`}
                    </DialogDescription>
                </DialogHeader>

                {/* Chain selection for listing */}
                {!nft.isListedForSale && (
                    <div className="space-y-4 py-4">
                        <div className="space-y-2">
                            <Label htmlFor="chain">Select Blockchain</Label>
                            <Select value={selectedChain} onValueChange={(value: "Sepolia" | "AvalancheFuji") => setSelectedChain(value)}>
                                <SelectTrigger>
                                    <SelectValue placeholder="Select blockchain" />
                                </SelectTrigger>
                                <SelectContent>
                                    {AVAILABLE_CHAINS.map((chain) => (
                                        <SelectItem key={chain.value} value={chain.value}>
                                            {chain.label}
                                        </SelectItem>
                                    ))}
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="rounded-lg bg-muted p-3 text-sm">
                            <p className="font-medium">NFT Details:</p>
                            <p>Price: {nft.price} ETH</p>
                            <p>Total Collateral: ${nft.totalCollateral.toLocaleString()}</p>
                            <p>Assets: {nft.assets.length} items</p>
                        </div>
                    </div>
                )}

                {/* Warning for removing from sale */}
                {nft.isListedForSale && (
                    <div className="py-4">
                        <div className="rounded-lg bg-amber-50 border border-amber-200 p-3 text-sm">
                            <p className="font-medium text-amber-800">⚠️ Warning</p>
                            <p className="text-amber-700">
                                This NFT will be removed from the marketplace and will no longer be visible to potential buyers.
                            </p>
                        </div>
                    </div>
                )}

                <DialogFooter>
                    <Button variant="outline" onClick={handleCancel}>
                        Cancel
                    </Button>
                    <Button
                        onClick={handleConfirm}
                        variant={nft.isListedForSale ? "destructive" : "default"}
                    >
                        {nft.isListedForSale ? "Remove from Sale" : "List for Sale"}
                    </Button>
                </DialogFooter>
            </DialogContent>
        </Dialog>
    )
}
