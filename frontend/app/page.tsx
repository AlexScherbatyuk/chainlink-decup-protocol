"use client"

import { useState } from "react"
import Header from "@/components/header"
import MainContent from "@/components/main-content"
import Footer from "@/components/footer"
import { NFTStoreProvider } from "@/store/nft-store"

type TabType = "on-sale" | "my-list" | "drafts"

export default function HomePage() {
  const [activeTab, setActiveTab] = useState<TabType>("on-sale")

  const handleTabChange = (tab: string) => {
    setActiveTab(tab as TabType)
  }

  return (
    <NFTStoreProvider>
      <div className="flex min-h-screen flex-col">
        <Header activeTab={activeTab} onTabChange={handleTabChange} />
        <MainContent activeTab={activeTab} />
        <Footer />
      </div>
    </NFTStoreProvider>
  )
}
