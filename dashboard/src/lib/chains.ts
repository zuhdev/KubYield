import { defineChain } from "viem";

export const kubMainnet = defineChain({
  id: 96,
  name: "KUB Chain",
  nativeCurrency: { name: "KUB", symbol: "KUB", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://rpc.kubchain.io"] },
  },
  blockExplorers: {
    default: { name: "KUB Scan", url: "https://kubscan.com" },
  },
});

export const kubTestnet = defineChain({
  id: 25925,
  name: "KUB Testnet",
  nativeCurrency: { name: "KUB", symbol: "KUB", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://rpc-testnet.kubchain.io"] },
  },
  blockExplorers: {
    default: { name: "KUB Testnet Scan", url: "https://testnet.kubscan.com" },
  },
  testnet: true,
});

export const supportedChains = [kubMainnet, kubTestnet] as const;

export function chainForId(chainId: number) {
  return chainId === kubTestnet.id ? kubTestnet : kubMainnet;
}

export function explorerAddressUrl(chainId: number, address: string) {
  return `${chainForId(chainId).blockExplorers.default.url}/address/${address}`;
}

export function explorerTxUrl(chainId: number, hash: string) {
  return `${chainForId(chainId).blockExplorers.default.url}/tx/${hash}`;
}
