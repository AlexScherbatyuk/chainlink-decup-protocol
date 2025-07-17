import { cacheExchange, createClient, fetchExchange } from 'urql'
import { useQuery } from 'urql'
import { custLog } from '../utils'

const getAPIURL = (chainId: number) => {
  if (chainId === 43113) {
    return 'https://api.studio.thegraph.com/query/115840/de-cup-manager-avalanche-fujy/version/latest'
  } else {
    return 'https://api.studio.thegraph.com/query/115840/decupmanager-sepolia/version/latest'
  }
}

export const createGraphQLClient = (chainId: number) => {
  return createClient({
    url: getAPIURL(chainId),
    exchanges: [
      cacheExchange,
      fetchExchange,
    ],
    fetchOptions: {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer 8132c2e80981876d4ed98bea7873d617',
      },
    },
  })
}


const salesQuery = `
  query {
    createSales {
      id
      saleId
      tokenId
      sellerAddress
      sourceChainId
      destinationChainId
      priceInUsd
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const crossSalesQuery = `
  query {
    createCrossSales {
      id
      tokenId
      sellerAddress
      sourceChainId
      destinationChainId
      priceInUsd
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const buysQuery = `
  query {
    buys {
      id
      saleId
      buyerAddress
      amountPaied
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const crossBuysQuery = `
  query {
    buyCrossSales {
      id
      saleId
      buyerAddress
      amountPaied
      sellerAddress
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const transfersQuery = `
  query {
    transfers {
      id
      from
      to
      tokenId
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const tokensListedQuery = `
  query {
    tokenListedForSales {
      id
      tokenId
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const tokensRemovedQuery = `
  query {
    tokenRemovedFromSales {
      id
      tokenId
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const depositsQuery = `
  query {
    deposits {
      id
      user
      amount
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const withdrawsQuery = `
  query {
    withdraws {
      id
      user
      amount
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const approvalsQuery = `
  query {
    approvals {
      id
      owner
      approved
      tokenId
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const cancelSalesQuery = `
  query {
    cancelSales {
      id
      saleId
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const cancelCrossSalesQuery = `
  query {
    cancelCrossSales {
      id
      tokenId
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const saleDeletedQuery = `
  query {
    saleDeleteds {
      id
      saleId
      tokenId
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

// Query by specific parameters
const saleByIdQuery = `
  query getSaleById($saleId: BigInt!) {
    createSales(where: { saleId: $saleId }) {
      id
      saleId
      tokenId
      sellerAddress
      sourceChainId
      destinationChainId
      priceInUsd
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const transfersByTokenQuery = `
  query getTransfersByToken($tokenId: BigInt!) {
    transfers(where: { tokenId: $tokenId }) {
      id
      from
      to
      tokenId
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const salesBySellerQuery = `
  query getSalesBySeller($sellerAddress: Bytes!) {
    createSales(where: { sellerAddress: $sellerAddress }) {
      id
      saleId
      tokenId
      sellerAddress
      sourceChainId
      destinationChainId
      priceInUsd
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

const buysByBuyerQuery = `
  query getBuysByBuyer($buyerAddress: Bytes!) {
    buys(where: { buyerAddress: $buyerAddress }) {
      id
      saleId
      buyerAddress
      amountPaied
      blockNumber
      blockTimestamp
      transactionHash
    }
  }
`

// Default client for backward compatibility (uses Sepolia)
//const defaultClient = createGraphQLClient(11155111)

//export default defaultClient

export const getSales = async (chainId: number) => {
  custLog('debug', '[GraphQL] getSales chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(salesQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getSales data:', data.data.createSales)
  return data
}

export const getCrossSales = async (chainId: number) => {
  custLog('debug', '[GraphQL] getCrossSales chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(crossSalesQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getCrossSales data:', data.data.createCrossSales)
  return data
}

export const getBuys = async (chainId: number) => {
  custLog('debug', '[GraphQL] getBuys chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(buysQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getBuys data:', data.data.buys)
  return data
}

export const getCrossBuys = async (chainId: number) => {
  custLog('debug', '[GraphQL] getCrossBuys chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(crossBuysQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getCrossBuys data:', data.data.buyCrossSales)
  return data
}

export const getTransfers = async (chainId: number) => {
  const client = createGraphQLClient(chainId)
  custLog('debug', '[GraphQL] getTransfers chainId: ', chainId)
  const data = await client.query(transfersQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getTransfers data:', data.data.transfers)
  return data
}

export const getTokensListed = async (chainId: number) => {
  custLog('debug', '[GraphQL] getTokensListed chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(tokensListedQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getTokensListed data:', data.data.tokenListedForSales)
  return data
}

export const getTokensRemoved = async (chainId: number) => {
  custLog('debug', '[GraphQL] getTokensRemoved chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(tokensRemovedQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getTokensRemoved data:', data.data.tokenRemovedFromSales)
  return data
}

export const getDeposits = async (chainId: number) => {
  custLog('debug', '[GraphQL] getDeposits chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(depositsQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getDeposits data:', data.data.deposits)
  return data
}

export const getWithdraws = async (chainId: number) => {
  custLog('debug', '[GraphQL] getWithdraws chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(withdrawsQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getWithdraws data:', data.data.withdraws)
  return data
}

export const getApprovals = async (chainId: number) => {
  custLog('debug', '[GraphQL] getApprovals chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(approvalsQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getApprovals data:', data.data.approvals)
  return data
}

export const getCancelSales = async (chainId: number) => {
  custLog('debug', '[GraphQL] getCancelSales chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(cancelSalesQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getCancelSales data:', data.data.cancelSales)
  return data
}

export const getCancelCrossSales = async (chainId: number) => {
  custLog('debug', '[GraphQL] getCancelCrossSales chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(cancelCrossSalesQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getCancelCrossSales data:', data.data.cancelCrossSales)
  return data
}

export const getSaleDeleteds = async (chainId: number) => {
  custLog('debug', '[GraphQL] getSaleDeleteds chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(saleDeletedQuery, {}).toPromise()
  custLog('debug', '[GraphQL] getSaleDeleteds data:', data.data.saleDeleteds)
  return data
}

// Functions with parameters
export const getSaleById = async (saleId: string, chainId: number) => {
  custLog('debug', '[GraphQL] getSaleById chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(saleByIdQuery, { saleId }).toPromise()
  custLog('debug', '[GraphQL] getSaleById data:', data.data.createSales)
  return data
}

export const getTransfersByToken = async (tokenId: string, chainId: number) => {
  custLog('debug', '[GraphQL] getTransfersByToken chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(transfersByTokenQuery, { tokenId }).toPromise()
  custLog('debug', '[GraphQL] getTransfersByToken data:', data.data.transfers)
  return data
}

export const getSalesBySeller = async (sellerAddress: string, chainId: number) => {
  custLog('debug', '[GraphQL] getSalesBySeller chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(salesBySellerQuery, { sellerAddress }).toPromise()
  custLog('debug', '[GraphQL] getSalesBySeller data:', data.data.createSales)
  return data
}

export const getBuysByBuyer = async (buyerAddress: string, chainId: number) => {
  custLog('debug', '[GraphQL] getBuysByBuyer chainId: ', chainId)
  const client = createGraphQLClient(chainId)
  const data = await client.query(buysByBuyerQuery, { buyerAddress }).toPromise()
  custLog('debug', '[GraphQL] getBuysByBuyer data:', data.data.buys)
  return data
}