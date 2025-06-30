const getContractAddresses = {
    11155111: {
        DeCup: "0xfD8bc17EEE6913d7bEbbc9682CF3e57fadAd5b90",
        DeCupManager: "0xB7FfAd7e75CC689BEcB0f63E5Ff4D91817D4f937",
    },
    43113: {
        DeCup: "0xf9233EA7f0FE5d3604fBC5A7b479cfC3011AF161", // Not deployed yet
        DeCupManager: "0xCCA170f4546F6a259374Bf0312d736D9872657f3", // Not deployed yet
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