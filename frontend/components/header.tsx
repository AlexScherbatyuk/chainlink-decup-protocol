"use client"
import { ChevronDown, Wallet } from "lucide-react"
import { Button } from "@/components/ui/button"
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu"

interface HeaderProps {
  activeTab?: string
  onTabChange?: (tab: string) => void
}

export default function Header({ activeTab = "on-sale", onTabChange }: HeaderProps) {
  const handleTabClick = (tab: string) => {
    if (onTabChange) {
      onTabChange(tab)
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
              <Button variant="outline" className="flex items-center space-x-2">
                <span>Sepolia</span>
                <ChevronDown className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem>
                <span>Sepolia</span>
              </DropdownMenuItem>
              <DropdownMenuItem>
                <span>Fuji</span>
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>

          <Button className="flex items-center space-x-2">
            <Wallet className="h-4 w-4" />
            <span>Connect Wallet</span>
          </Button>
        </div>
      </div>
    </header>
  )
}
