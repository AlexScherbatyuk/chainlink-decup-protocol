"use client"

import OnSaleContent from "./tabs/on-sale-content"
import MyListContent from "./tabs/my-list-content"
import DraftsContent from "./tabs/drafts-content"

type TabType = "on-sale" | "my-list" | "drafts"

interface MainContentProps {
  activeTab?: TabType
}

export default function MainContent({ activeTab = "on-sale" }: MainContentProps) {
  switch (activeTab) {
    case "on-sale":
      return <OnSaleContent />
    case "my-list":
      return <MyListContent />
    case "drafts":
      return <DraftsContent />
    default:
      return <OnSaleContent />
  }
}
