const getContractAddresses = {
    11155111: {
        DeCup: "0x9aa2A89e8e91716b19411536a615Fa5Ffc329D03",
        DeCupManager: "0xeb6Af8066126a6B9c3f5aeCD93506dE8C9599000",
    },
    43113: {
        DeCup: "0xcD37F06Ad1c8675642577b9E60fdC86138017F08", // Not deployed yet
        DeCupManager: "0xC2D71b66809Dbf3353D741F548402aB9915dDf76", // Not deployed yet
    }
} as const

const getTokenAddresses = {
    11155111: {//sepolia
        WETH: "0xdd13E55209Fd76AfE204dBda4007C227904f0a81",
        USDC: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
        ETH: "0x0000000000000000000000000000000000000000"
    },
    43113: {//avalancheFuji
        WAVAX: "0xd00ae08403B9bbb9124bB305C09058E32C39A48c",
        USDC: "0x5425890298aed601595a70AB815c96711a31Bc65",
        AVAX: "0x0000000000000000000000000000000000000000"
    }
} as const

const getTokenSymbols = {
    11155111: {//sepolia
        "0xdd13E55209Fd76AfE204dBda4007C227904f0a81": "WETH",
        "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238": "USDC",
        "0x0000000000000000000000000000000000000000": "ETH"
    },
    43113: {//avalancheFuji
        "0xd00ae08403B9bbb9124bB305C09058E32C39A48c": "WAVAX",
        "0x5425890298aed601595a70AB815c96711a31Bc65": "USDC",
        "0x0000000000000000000000000000000000000000": "AVAX"
    }
} as const

export {
    getContractAddresses,
    getTokenAddresses,
    getTokenSymbols
}