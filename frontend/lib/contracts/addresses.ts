const getContractAddresses = {
    11155111: {
        DeCup: "0x8580edC0bb66C52e5097A0998d8eAEb7C2D0b114",
        DeCupManager: "0xa5d8d7950Bcf65BE5fED367cc618E7118c9d81d6",
    },
    43113: {
        DeCup: "0x0000000000000000000000000000000000000000", // Not deployed yet
        DeCupManager: "0x0000000000000000000000000000000000000000", // Not deployed yet
    }
} as const

const getTokenAddresses = {
    11155111: {//sepolia
        WETH: "0xdd13E55209Fd76AfE204dBda4007C227904f0a81",
        USDC: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
    },
    43113: {//avalancheFuji
        WAVAX: "0xd00ae08403B9bbb9124bB305C09058E32C39A48c",
        USDC: "0x5425890298aed601595a70AB815c96711a31Bc65"
    }
} as const

export {
    getContractAddresses,
    getTokenAddresses
}