"use client"

import { Button } from "@/components/ui/button"
import {
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { type DeCupNFT } from "@/store/nft-store"

interface DeleteModalProps {
    isOpen: boolean
    onClose: () => void
    nft: DeCupNFT | null
    onConfirm: () => void
}

export default function DeleteModal({ isOpen, onClose, nft, onConfirm }: DeleteModalProps) {
    const handleConfirm = () => {
        onConfirm()
    }

    const handleCancel = () => {
        onClose()
    }

    if (!nft) return null

    return (
        <AlertDialog open={isOpen} onOpenChange={onClose}>
            <AlertDialogContent>
                <AlertDialogHeader>
                    <AlertDialogTitle>Delete NFT</AlertDialogTitle>
                    <AlertDialogDescription>
                        Are you sure you want to delete NFT #{nft.tokenId}? This action cannot be undone.
                        {nft.isListedForSale && (
                            <span className="block mt-2 text-amber-600 font-medium">
                                ⚠️ This NFT is currently listed for sale and will be removed from the marketplace.
                            </span>
                        )}
                    </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                    <AlertDialogCancel onClick={handleCancel}>Cancel</AlertDialogCancel>
                    <AlertDialogAction
                        onClick={handleConfirm}
                        className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                    >
                        Delete NFT
                    </AlertDialogAction>
                </AlertDialogFooter>
            </AlertDialogContent>
        </AlertDialog>
    )
} 