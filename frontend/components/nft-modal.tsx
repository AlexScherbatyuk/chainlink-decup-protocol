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
import { depositNative, depositERC20, getTokenPriceInUsd, withdrawNativeDeCupManager, burnDeCupNFT, listDeCupNFTForSale, removeDeCupNFTFromSale } from "@/lib/contracts/interaction"
import { getContractAddresses, getTokenAddresses } from "@/lib/contracts/addresses"
import { useAccount, useChainId, useSwitchChain } from 'wagmi'


interface NFTModalProps {
  isOpen: boolean
  onClose: () => void
  mode: "create" | "edit"
  nftId?: string
}

const AVAILABLE_TOKENS = [
  { value: "USDC", label: "USDC - USD Coin" },
  { value: "WAVAX", label: "WAVAX - Wrapped Avalanche" },
  { value: "WETH", label: "WETH - Wrapped Ethereum" },
  { value: "Native", label: "Native currency" },
]

const AVAILABLE_CHAINS = [
  { value: "Sepolia", label: "Sepolia Testnet" },
  { value: "Fuji", label: "Avalanche Fuji" },
]

const AVAILABLE_CHAINS_BY_ID = [
  { value: 11155111, label: "Sepolia Testnet" },
  { value: 43113, label: "Avalanche Fuji" },
]

export default function NFTModal({ isOpen, onClose, mode, nftId }: NFTModalProps) {
  const { getNFTById, createNFT, updateNFT, getTotalCollateral } = useNFTStore()
  const chainId = useChainId()
  const { address, isConnected } = useAccount()

  const [tokenPrice, setTokenPrice] = useState<number>(0)
  const [totalCollateralInUsd, setTotalCollateralInUsd] = useState<number>(0)

  const [formData, setFormData] = useState<NFTFormData>({
    price: 0,
    marketPrice: true,
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
          marketPrice: nft.marketPrice,
          assets: nft.assets,
          chain: nft.chain,
          beneficialWallet: nft.beneficialWallet,
        })
      }
    } else {
      // Reset form for create mode
      setFormData({
        price: 0,
        marketPrice: true,
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
    // if (!newAsset.walletAddress) {
    //   newErrors.walletAddress = "Please enter a wallet address"
    // } else if (!validateWalletAddress(newAsset.walletAddress)) {
    //   newErrors.walletAddress = "Please enter a valid Ethereum address (0x...)"
    // }

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors)
      return
    }

    const asset: Asset = {
      id: `asset-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      token: newAsset.token,
      amount: Number.parseFloat(newAsset.amount),
      walletAddress: formData.beneficialWallet, //newAsset.walletAddress,
      deposited: false,
    }

    setFormData((prev) => ({
      ...prev,
      assets: [...prev.assets, asset],
    }))

    setNewAsset({ token: "", amount: "", walletAddress: "" })
    setErrors({})
  }

  const handleRemoveAsset = (asset: Asset) => {
    if (asset.deposited) {
      console.log("Asset already deposited:", asset.id, " to withdraw DeCup NFT must be burn")
      return
    }

    setFormData((prev) => ({
      ...prev,
      assets: prev.assets.filter((asset) => asset.id !== asset.id),
    }))
  }

  const handleDeposit = async (asset: Asset) => {
    if (asset.deposited) {
      console.log("Asset already deposited:", asset.id, " to remove asset must be deposited")
      return
    }

    // Check if wallet is connected
    if (!isConnected || !address) {
      alert("Please connect your wallet first to deposit assets.")
      return
    }

    let success = false
    let assetTokenId: string = asset.id
    const contracts = getContractAddresses[chainId as keyof typeof getContractAddresses]

    // Convert decimal amount to wei (multiply by 10^18 for 18 decimal places)
    const amountInWei = BigInt(Math.floor(asset.amount * Math.pow(10, 18)))

    try {
      if (asset.token === "Native") {
        const result = await depositNative(amountInWei, contracts.DeCup, address)
        success = result.success
        if (result.success && result.tokenId) {
          assetTokenId = result.tokenId.toString()
        }
      } else {
        const result = await depositERC20(amountInWei, (getTokenAddresses[chainId as keyof typeof getTokenAddresses] as any)[asset.token], contracts.DeCup, address)
        success = result.success
        if (result.success && result.tokenId) {
          assetTokenId = result.tokenId.toString()
        }
      }

      if (success) {
        setFormData((prev) => ({
          ...prev,
          assets: prev.assets.map((storedAsset) =>
            storedAsset.id === asset.id ? { ...storedAsset, deposited: !storedAsset.deposited, id: assetTokenId } : storedAsset
          ),
        }))
        console.log("Asset deposited successfully:", assetTokenId)
      }
    } catch (error) {
      console.error("Failed to deposit asset:", error)
      alert("Failed to deposit asset. Please check your wallet connection and try again.")
    }
  }

  const handleSave = () => {
    const saveErrors: Record<string, string> = {}

    if (!formData.marketPrice) {
      if (!formData.price || formData.price <= 0) {
        saveErrors.price = "Please enter a valid price"
      }
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

  useEffect(() => {
    if (formData.assets.length > 0) {
      const requestTokenCollateral = async () => {
        const contracts = getContractAddresses[chainId as keyof typeof getContractAddresses]
        const asset = formData.assets[0]
        // Only get price if asset is deposited and has a valid tokenId
        console.log("asset tokenId", asset.id)
        if (asset.deposited && asset.id && !isNaN(Number(asset.id))) {
          const totalCollateral: { price: number } = await getTokenPriceInUsd(BigInt(asset.id), contracts.DeCup)
          setTotalCollateralInUsd(Number(totalCollateral.price) / 100000000)
        }
      }
      requestTokenCollateral()
    } else {
      setTotalCollateralInUsd(0)
    }
  }, [isOpen, formData.assets.length, chainId])


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
              <Label htmlFor="beneficialWallet">Beneficial Wallet Address</Label>
              <Input
                id="beneficialWallet"
                placeholder={address || "0x..."}
                value={formData.beneficialWallet || address || ""}
                onChange={(e) => setFormData((prev) => ({ ...prev, beneficialWallet: e.target.value || address || "" }))}
              />
              {errors.beneficialWallet && <p className="text-sm text-red-500">{errors.beneficialWallet}</p>}
            </div>

            <div className="space-y-2">
              <Label htmlFor="chain">Chain to sale NFT</Label>
              <Select
                value={formData.chain}
                onValueChange={(value: "Sepolia" | "AvalancheFuji") => setFormData((prev) => ({ ...prev, chain: value }))}
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

                {/*<div className="space-y-2">
                  <Label htmlFor="assetWallet">Wallet Address</Label>
                  <Input
                    id="assetWallet"
                    placeholder="0x..."
                    value={newAsset.walletAddress}
                    onChange={(e) => setNewAsset((prev) => ({ ...prev, walletAddress: e.target.value }))}
                  />
                  {errors.walletAddress && <p className="text-sm text-red-500">{errors.walletAddress}</p>}
                </div>*/}

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
                Total Collateral: ${totalCollateralInUsd.toLocaleString()}
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
                          {asset.deposited && <Badge variant="default" className="bg-green-500">Deposited</Badge>}
                        </div>
                        <Button size="sm" variant="outline" onClick={() => handleRemoveAsset(asset)} disabled={asset.deposited} title="To remove asset DeCup NFT mus be burn">
                          <Trash2 className="h-3 w-3" />
                        </Button>
                      </div>
                      <div className="space-y-2">
                        {/*<div className="text-xs text-muted-foreground">
                          Wallet: {asset.walletAddress.slice(0, 6)}...{asset.walletAddress.slice(-4)}
                        </div>*/}
                        <Button
                          size="sm"
                          className="w-full"
                          onClick={() => handleDeposit(asset)}
                          variant={asset.deposited ? "outline" : "default"}
                          disabled={asset.deposited || !isConnected}
                        >
                          <Wallet className="h-3 w-3 mr-2" />
                          {!isConnected ? "Connect Wallet" : asset.deposited ? "Deposited" : "Deposit"}
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
