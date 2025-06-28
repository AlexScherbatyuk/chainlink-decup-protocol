const getChainNameById = {
    11155111: "Sepolia",
    43113: "AvalancheFuji"
} as const

const getChainIdByName = {
    "Sepolia": 11155111,
    "AvalancheFuji": 43113
} as const

export { getChainNameById, getChainIdByName }