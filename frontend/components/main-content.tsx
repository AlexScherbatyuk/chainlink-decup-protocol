"use client"

import OnSaleContent from "./tabs/on-sale-content"
import MyListContent from "./tabs/my-list-content"
import { NFTProvider } from "@/contexts/nft-context"

type TabType = "on-sale" | "my-list" | "drafts"

interface MainContentProps {
  activeTab?: TabType
}

export default function MainContent({ activeTab = "on-sale" }: MainContentProps) {
  return (
    <NFTProvider>
      {(() => {
        switch (activeTab) {
          case "on-sale":
            return <OnSaleContent />
          case "my-list":
            return <MyListContent />
          default:
            return <OnSaleContent />
        }
      })()}
    </NFTProvider>
  )
}
