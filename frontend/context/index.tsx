'use client'

import React, { ReactNode } from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WagmiProvider, cookieToInitialState, type Config } from 'wagmi'
import { createAppKit } from '@reown/appkit/react'
// Import config, networks, projectId, and wagmiAdapter from your config file
import { config, networks, projectId, wagmiAdapter, sepolia, avalancheFuji } from '@/config'
import { custLog } from '@/lib/utils'

const queryClient = new QueryClient()

const metadata = {
    name: 'Chromion DeCup',
    description: 'Decentralized Cup Trading Platform',
    url: typeof window !== 'undefined' ? window.location.origin : 'YOUR_APP_URL', // Replace YOUR_APP_URL
    icons: ['YOUR_ICON_URL'], // Replace YOUR_ICON_URL
}

// Initialize AppKit *outside* the component render cycle
// Add a check for projectId for type safety, although config throws error already.
if (!projectId) {
    custLog('error', '[context:index] AppKit Initialization Error: Project ID is missing.')
    // Optionally throw an error or render fallback UI
} else {
    createAppKit({
        adapters: [wagmiAdapter],
        // Use non-null assertion `!` as projectId is checked runtime, needed for TypeScript
        projectId: projectId!,
        // Pass networks directly (type is now correctly inferred from config)
        networks: networks,
        defaultNetwork: sepolia, // Default to Sepolia testnet
        metadata,
        features: { analytics: true }, // Optional features
        themeMode: 'light', // or 'light'
        themeVariables: {
            '--w3m-accent': '#000000', // Primary button color
        }
    })
}

export default function ContextProvider({
    children,
    cookies,
}: {
    children: ReactNode
    cookies: string | null // Cookies from server for hydration
}) {
    // Calculate initial state for Wagmi SSR hydration
    const initialState = cookieToInitialState(config as Config, cookies)

    return (
        // Cast config as Config for WagmiProvider
        <WagmiProvider config={config as Config} initialState={initialState}>
            <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
        </WagmiProvider>
    )
} 