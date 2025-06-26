"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Trash2, Plus, Wallet } from "lucide-react"
import { useNFTStore, type Asset, type NFTFormData } from "@/store/nft-store"

interface NFTModalProps {
  isOpen: boolean
  onClose: () => void
  mode: "create" | "edit"
  nftId?: string
}

const AVAILABLE_TOKENS = [
  { value: "USDC", label: "USDC - USD Coin" },
  { value: "USDT", label: "USDT - Tether USD" },
  { value: "DAI", label: "DAI - Dai Stablecoin" },
  { value: "ETH", label: "ETH - Ethereum" },
  { value: "WETH", label: "WETH - Wrapped Ethereum" },
]

const AVAILABLE_CHAINS = [
  { value: "Sepolia", label: "Sepolia Testnet" },
  { value: "Fuji", label: "Avalanche Fuji" },
]

export default function NFTModal({ isOpen, onClose, mode, nftId }: NFTModalProps) {
  const { getNFTById, createNFT, updateNFT, getTotalCollateral } = useNFTStore()

  const [formData, setFormData] = useState<NFTFormData>({
    price: 0,
    assets: [],
    chain: "Sepolia",
    beneficialWallet: "",
  })

  const [newAsset, setNewAsset] = useState({
    token: "",
    amount: "",
    walletAddress: "",
  })

  const [errors, setErrors] = useState<Record<string, string>>({})

  // Load NFT data for edit mode
  useEffect(() => {
    if (mode === "edit" && nftId) {
      const nft = getNFTById(nftId)
      if (nft) {
        setFormData({
          tokenId: nft.tokenId,
          price: nft.price,
          assets: nft.assets,
          chain: nft.chain,
          beneficialWallet: nft.beneficialWallet,
        })
      }
    } else {
      // Reset form for create mode
      setFormData({
        price: 0,
        assets: [],
        chain: "Sepolia",
        beneficialWallet: "",
      })
    }
  }, [mode, nftId, getNFTById])

  const validateWalletAddress = (address: string): boolean => {
    // Basic Ethereum address validation (0x followed by 40 hex characters)
    const ethAddressRegex = /^0x[a-fA-F0-9]{40}$/
    return ethAddressRegex.test(address)
  }

  const handleAddAsset = () => {
    const newErrors: Record<string, string> = {}

    if (!newAsset.token) {
      newErrors.token = "Please select a token"
    }
    if (!newAsset.amount || Number.parseFloat(newAsset.amount) <= 0) {
      newErrors.amount = "Please enter a valid amount"
    }
    if (!newAsset.walletAddress) {
      newErrors.walletAddress = "Please enter a wallet address"
    } else if (!validateWalletAddress(newAsset.walletAddress)) {
      newErrors.walletAddress = "Please enter a valid Ethereum address (0x...)"
    }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors)
      return
    }

    const asset: Asset = {
      id: `asset-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      token: newAsset.token,
      amount: Number.parseFloat(newAsset.amount),
      walletAddress: newAsset.walletAddress,
    }

    setFormData((prev) => ({
      ...prev,
      assets: [...prev.assets, asset],
    }))

    setNewAsset({ token: "", amount: "", walletAddress: "" })
    setErrors({})
  }

  const handleRemoveAsset = (assetId: string) => {
    setFormData((prev) => ({
      ...prev,
      assets: prev.assets.filter((asset) => asset.id !== assetId),
    }))
  }

  const handleDeposit = (assetId: string) => {
    console.log("Deposit asset:", assetId)
    // Implement deposit functionality
  }

  const handleSave = () => {
    const saveErrors: Record<string, string> = {}

    if (!formData.price || formData.price <= 0) {
      saveErrors.price = "Please enter a valid price"
    }
    if (!formData.beneficialWallet) {
      saveErrors.beneficialWallet = "Please enter a beneficial wallet address"
    } else if (!validateWalletAddress(formData.beneficialWallet)) {
      saveErrors.beneficialWallet = "Please enter a valid Ethereum address (0x...)"
    }
    if (formData.assets.length === 0) {
      saveErrors.assets = "Please add at least one asset"
    }

    if (Object.keys(saveErrors).length > 0) {
      setErrors(saveErrors)
      return
    }

    if (mode === "create") {
      createNFT(formData)
    } else if (mode === "edit" && nftId) {
      updateNFT(nftId, formData)
    }

    onClose()
  }

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{mode === "create" ? "Create New DeCup NFT" : "Edit DeCup NFT"}</DialogTitle>
          <DialogDescription>
            {mode === "create"
              ? "Configure your new DeCup NFT with collateralized assets"
              : "Update your DeCup NFT configuration"}
          </DialogDescription>
        </DialogHeader>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Left Column - NFT Details */}
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="price">Price (ETH)</Label>
              <Input
                id="price"
                type="number"
                step="0.01"
                placeholder="0.00"
                value={formData.price || ""}
                onChange={(e) => setFormData((prev) => ({ ...prev, price: Number.parseFloat(e.target.value) || 0 }))}
              />
              {errors.price && <p className="text-sm text-red-500">{errors.price}</p>}
            </div>

            <div className="space-y-2">
              <Label htmlFor="beneficialWallet">Beneficial Wallet Address</Label>
              <Input
                id="beneficialWallet"
                placeholder="0x..."
                value={formData.beneficialWallet}
                onChange={(e) => setFormData((prev) => ({ ...prev, beneficialWallet: e.target.value }))}
              />
              {errors.beneficialWallet && <p className="text-sm text-red-500">{errors.beneficialWallet}</p>}
            </div>

            <div className="space-y-2">
              <Label htmlFor="chain">Chain</Label>
              <Select
                value={formData.chain}
                onValueChange={(value: "Sepolia" | "Fuji") => setFormData((prev) => ({ ...prev, chain: value }))}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Select chain" />
                </SelectTrigger>
                <SelectContent>
                  {AVAILABLE_CHAINS.map((chain) => (
                    <SelectItem key={chain.value} value={chain.value}>
                      {chain.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Add New Asset Form */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Add New Asset</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="token">Token</Label>
                  <Select
                    value={newAsset.token}
                    onValueChange={(value) => setNewAsset((prev) => ({ ...prev, token: value }))}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select token" />
                    </SelectTrigger>
                    <SelectContent>
                      {AVAILABLE_TOKENS.map((token) => (
                        <SelectItem key={token.value} value={token.value}>
                          {token.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                  {errors.token && <p className="text-sm text-red-500">{errors.token}</p>}
                </div>

                <div className="space-y-2">
                  <Label htmlFor="amount">Amount</Label>
                  <Input
                    id="amount"
                    type="number"
                    step="0.01"
                    placeholder="0.00"
                    value={newAsset.amount}
                    onChange={(e) => setNewAsset((prev) => ({ ...prev, amount: e.target.value }))}
                  />
                  {errors.amount && <p className="text-sm text-red-500">{errors.amount}</p>}
                </div>

                <div className="space-y-2">
                  <Label htmlFor="assetWallet">Wallet Address</Label>
                  <Input
                    id="assetWallet"
                    placeholder="0x..."
                    value={newAsset.walletAddress}
                    onChange={(e) => setNewAsset((prev) => ({ ...prev, walletAddress: e.target.value }))}
                  />
                  {errors.walletAddress && <p className="text-sm text-red-500">{errors.walletAddress}</p>}
                </div>

                <Button onClick={handleAddAsset} className="w-full">
                  <Plus className="h-4 w-4 mr-2" />
                  Add Asset
                </Button>
              </CardContent>
            </Card>
          </div>

          {/* Right Column - Assets List */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold">Assets ({formData.assets.length})</h3>
              <div className="text-sm text-muted-foreground">
                Total Collateral: ${getTotalCollateral(formData.assets).toLocaleString()}
              </div>
            </div>

            {errors.assets && <p className="text-sm text-red-500">{errors.assets}</p>}

            <div className="space-y-3 max-h-96 overflow-y-auto">
              {formData.assets.length === 0 ? (
                <Card>
                  <CardContent className="p-6 text-center text-muted-foreground">
                    No assets added yet. Add your first asset to get started.
                  </CardContent>
                </Card>
              ) : (
                formData.assets.map((asset) => (
                  <Card key={asset.id}>
                    <CardContent className="p-4">
                      <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center space-x-2">
                          <Badge variant="secondary">{asset.token}</Badge>
                          <span className="font-semibold">{asset.amount.toLocaleString()}</span>
                        </div>
                        <Button size="sm" variant="outline" onClick={() => handleRemoveAsset(asset.id)}>
                          <Trash2 className="h-3 w-3" />
                        </Button>
                      </div>
                      <div className="space-y-2">
                        <div className="text-xs text-muted-foreground">
                          Wallet: {asset.walletAddress.slice(0, 6)}...{asset.walletAddress.slice(-4)}
                        </div>
                        <Button size="sm" className="w-full" onClick={() => handleDeposit(asset.id)}>
                          <Wallet className="h-3 w-3 mr-2" />
                          Deposit
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                ))
              )}
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancel
          </Button>
          <Button onClick={handleSave}>{mode === "create" ? "Create NFT" : "Save Changes"}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
