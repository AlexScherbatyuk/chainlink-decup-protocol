"use client"

import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { X, CheckCircle, AlertCircle, Info } from "lucide-react"
import { cn } from "@/lib/utils"
import { useToastStore, type Toast } from "@/store/toast-store"

const toastVariants = cva(
  "group pointer-events-auto relative flex w-full items-center justify-between space-x-4 overflow-hidden rounded-md border p-4 pr-8 shadow-lg transition-all data-[swipe=cancel]:translate-x-0 data-[swipe=end]:translate-x-[var(--radix-toast-swipe-end-x)] data-[swipe=move]:translate-x-[var(--radix-toast-swipe-move-x)] data-[swipe=move]:transition-none data-[state=open]:animate-in data-[state=closed]:animate-out data-[swipe=end]:animate-out data-[state=closed]:fade-out-80 data-[state=closed]:slide-out-to-right-full data-[state=open]:slide-in-from-top-full data-[state=open]:sm:slide-in-from-bottom-full",
  {
    variants: {
      variant: {
        default: "border bg-background text-foreground",
        destructive: "destructive group border-destructive bg-destructive text-destructive-foreground",
        success:
          "border-green-200 bg-green-50 text-green-900 dark:border-green-800 dark:bg-green-900/20 dark:text-green-100",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  },
)

interface ToastComponentProps extends VariantProps<typeof toastVariants> {
  toast: Toast
}

const ToastComponent = React.forwardRef<HTMLDivElement, ToastComponentProps>(({ toast, variant, ...props }, ref) => {
  const removeToast = useToastStore((state) => state.removeToast)

  const getIcon = () => {
    switch (variant || toast.variant) {
      case "success":
        return <CheckCircle className="h-5 w-5 text-green-600" />
      case "destructive":
        return <AlertCircle className="h-5 w-5 text-red-600" />
      default:
        return <Info className="h-5 w-5 text-blue-600" />
    }
  }

  return (
    <div ref={ref} className={cn(toastVariants({ variant: variant || toast.variant }))} {...props}>
      <div className="flex items-start space-x-3">
        {getIcon()}
        <div className="flex-1 space-y-1">
          {toast.title && <div className="text-sm font-semibold">{toast.title}</div>}
          {toast.description && <div className="text-sm opacity-90">{toast.description}</div>}
        </div>
      </div>
      <button
        onClick={() => removeToast(toast.id)}
        className="absolute right-2 top-2 rounded-md p-1 text-foreground/50 opacity-0 transition-opacity hover:text-foreground focus:opacity-100 focus:outline-none focus:ring-2 group-hover:opacity-100"
      >
        <X className="h-4 w-4" />
      </button>
    </div>
  )
})
ToastComponent.displayName = "Toast"

export { ToastComponent, toastVariants }
