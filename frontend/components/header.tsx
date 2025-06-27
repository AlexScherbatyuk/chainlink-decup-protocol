"use client"
import { ChevronDown, Wallet } from "lucide-react"
import { Button } from "@/components/ui/button"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"
import { useAccount, useChainId, useSwitchChain } from 'wagmi'
import { sepolia, avalancheFuji } from '@/config'
import { useEffect, useState } from 'react'

interface HeaderProps {
  activeTab?: string
  onTabChange?: (tab: string) => void
}

// Network configurations
const supportedNetworks = [
  {
    chain: sepolia,
    name: "Sepolia",
    chainId: 11155111
  },
  {
    chain: avalancheFuji,
    name: "Fuji",
    chainId: 43113
  }
]

export default function Header({ activeTab = "on-sale", onTabChange }: HeaderProps) {
  const { isConnected } = useAccount()
  const chainId = useChainId()
  const { switchChain } = useSwitchChain()
  const [currentNetwork, setCurrentNetwork] = useState<string>("Sepolia")

  // Update current network display based on connected chain
  useEffect(() => {
    if (isConnected && chainId) {
      const network = supportedNetworks.find(net => net.chainId === chainId)
      setCurrentNetwork(network?.name || "Unknown")
    }
  }, [chainId, isConnected])

  const handleTabClick = (tab: string) => {
    if (onTabChange) {
      onTabChange(tab)
    }
  }

  const handleNetworkSwitch = (network: { chain: any; name: string; chainId: number }) => {
    if (isConnected && switchChain) {
      switchChain({ chainId: network.chainId })
    }
  }

  return (
    <header className="flex justify-center sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      <div className="container flex h-14 items-center justify-between">
        {/* Left side - Navigation tabs */}
        <nav className="flex items-center space-x-6">
          <button
            onClick={() => handleTabClick("on-sale")}
            className={`text-sm font-medium transition-colors hover:text-primary ${activeTab === "on-sale" ? "text-foreground" : "text-muted-foreground"
              }`}
          >
            On sale
          </button>
          <button
            onClick={() => handleTabClick("my-list")}
            className={`text-sm font-medium transition-colors hover:text-primary ${activeTab === "my-list" ? "text-foreground" : "text-muted-foreground"
              }`}
          >
            My list
          </button>
          <button
            onClick={() => handleTabClick("drafts")}
            className={`text-sm font-medium transition-colors hover:text-primary ${activeTab === "drafts" ? "text-foreground" : "text-muted-foreground"
              }`}
          >
            Drafts
          </button>
        </nav>

        {/* Right side - Blockchain dropdown and Connect Wallet */}
        <div className="flex items-center space-x-4">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" className="flex items-center space-x-2" disabled={!isConnected}>
                <span>{currentNetwork}</span>
                <ChevronDown className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {supportedNetworks.map((network) => (
                <DropdownMenuItem
                  key={network.chainId}
                  onClick={() => handleNetworkSwitch(network)}
                  className={chainId === network.chainId ? "bg-accent" : ""}
                >
                  <span>{network.name}</span>
                  {chainId === network.chainId && (
                    <span className="ml-2 text-xs text-green-600">●</span>
                  )}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
          <div className="text-black">
            <appkit-button />
          </div>
        </div>
      </div>
    </header>
  )
}
