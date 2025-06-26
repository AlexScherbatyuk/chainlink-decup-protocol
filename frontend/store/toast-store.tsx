"use client"

import { create } from "zustand"
import { subscribeWithSelector } from "zustand/middleware"

export interface Toast {
  id: string
  title?: string
  description?: string
  variant?: "default" | "destructive" | "success"
  duration?: number
}

interface ToastStore {
  toasts: Toast[]
  addToast: (toast: Omit<Toast, "id">) => string
  removeToast: (id: string) => void
  clearAllToasts: () => void
}

let toastCount = 0

export const useToastStore = create<ToastStore>()(
  subscribeWithSelector((set, get) => ({
    toasts: [],

    addToast: (toast) => {
      const id = `toast-${++toastCount}`
      const newToast: Toast = {
        id,
        duration: 5000,
        variant: "default",
        ...toast,
      }

      set((state) => ({
        toasts: [...state.toasts, newToast],
      }))

      // Auto remove toast after duration
      if (newToast.duration && newToast.duration > 0) {
        setTimeout(() => {
          get().removeToast(id)
        }, newToast.duration)
      }

      return id
    },

    removeToast: (id) => {
      set((state) => ({
        toasts: state.toasts.filter((toast) => toast.id !== id),
      }))
    },

    clearAllToasts: () => {
      set({ toasts: [] })
    },
  })),
)

// Convenience functions
export const toast = {
  success: (message: string, description?: string) => {
    return useToastStore.getState().addToast({
      title: message,
      description,
      variant: "success",
    })
  },

  error: (message: string, description?: string) => {
    return useToastStore.getState().addToast({
      title: message,
      description,
      variant: "destructive",
    })
  },

  info: (message: string, description?: string) => {
    return useToastStore.getState().addToast({
      title: message,
      description,
      variant: "default",
    })
  },

  custom: (toast: Omit<Toast, "id">) => {
    return useToastStore.getState().addToast(toast)
  },
}
