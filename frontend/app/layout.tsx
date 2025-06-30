import type { Metadata } from 'next'
import { Inter } from 'next/font/google' // Or your preferred font
import './globals.css'

import { headers } from 'next/headers' // Import headers function
import ContextProvider from '@/context' // Adjust import path if needed

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'DeCup',
  description: 'DeCup is a platform for creating and trading NFTs with collateralized assets',
  generator: 'DeCup',
}

// ATTENTION!!! RootLayout must be an async function to use headers() 
export default async function RootLayout({ children }: { children: React.ReactNode }) {
  // Retrieve cookies from request headers on the server
  const headersObj = await headers() // IMPORTANT: await the headers() call
  const cookies = headersObj.get('cookie')

  return (
    <html lang="en">
      <body className={inter.className}>
        {/* Wrap children with ContextProvider, passing cookies */}
        <ContextProvider cookies={cookies}>{children}</ContextProvider>
      </body>
    </html>
  )
}
