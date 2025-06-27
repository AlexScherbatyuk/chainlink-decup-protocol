const getContractAddresses = {
    sepolia: {
        DeCup: "0x0e3da2602e33acb76f925f379dc7b2e1c5d4fefb",
        DeCupManager: "0xa5d8d7950bcf65be5fed367cc618e7118c9d81d6",
    },
    avalancheFuji: {
        DeCup: "0x0000000000000000000000000000000000000000", // Not deployed yet
        DeCupManager: "0x0000000000000000000000000000000000000000", // Not deployed yet
    }
} as const

const getTokenAddresses = {
    sepolia: {
        WETH: "0xdd13E55209Fd76AfE204dBda4007C227904f0a81",
        USDC: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
    },
    avalancheFuji: {
        WAVAX: "0xd00ae08403B9bbb9124bB305C09058E32C39A48c",
        USDC: "0x5425890298aed601595a70AB815c96711a31Bc65"
    }
} as const

export {
    getContractAddresses,
    getTokenAddresses
}