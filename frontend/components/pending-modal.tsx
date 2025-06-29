"use client"

import { Button } from "@/components/ui/button"
import {
    AlertDialog,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogHeader,
    AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Loader2, X } from "lucide-react"

interface PendingModalProps {
    isOpen: boolean
    onClose: () => void
    title?: string
    message?: string
    transactionType?: string
}

export default function PendingModal({
    isOpen,
    onClose,
    title = "Transaction Pending",
    message = "Please wait while your transaction is being processed...",
    transactionType = "transaction"
}: PendingModalProps) {
    return (
        <AlertDialog open={isOpen}>
            <AlertDialogContent className="sm:max-w-md">
                <button
                    onClick={onClose}
                    className="absolute right-4 top-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 disabled:pointer-events-none"
                >
                    <X className="h-4 w-4" />
                    <span className="sr-only">Close</span>
                </button>
                <AlertDialogHeader>
                    <AlertDialogTitle className="flex items-center gap-2">
                        <Loader2 className="h-5 w-5 animate-spin" />
                        {title}
                    </AlertDialogTitle>
                    <AlertDialogDescription className="text-center py-4">
                        <span className="flex flex-col items-center gap-3">
                            <span className="text-base block">
                                {message}
                            </span>
                            <span className="text-sm text-muted-foreground block">
                                Your {transactionType} is being processed on the blockchain.
                                This may take a few moments.
                            </span>
                            <span className="text-sm text-amber-600 font-medium block">
                                ⚠️ Please do not close this window or navigate away
                            </span>
                        </span>
                    </AlertDialogDescription>
                </AlertDialogHeader>
            </AlertDialogContent>
        </AlertDialog>
    )
} 