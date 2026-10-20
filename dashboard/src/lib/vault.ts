import { parseAbi, type Address } from "viem";

export const vaultAbi = parseAbi([
  "function underlying() view returns (address)",
  "function sharesToken() view returns (address)",
  "function totalAssets() view returns (uint256)",
  "function accountedAssets() view returns (uint256)",
  "function strategy() view returns (address)",
  "function paused() view returns (bool)",
  "function HARVEST_FEE_BPS() view returns (uint256)",
  "function previewRedeem(uint256 shares) view returns (uint256)",
  "function convertToAssets(uint256 shares) view returns (uint256)",
  "function deposit(uint256 assets) returns (uint256)",
  "function withdraw(uint256 shares) returns (uint256)",
  "function harvest() returns (uint256)",
  "event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares)",
  "event Withdraw(address indexed caller, address indexed receiver, uint256 assets, uint256 shares)",
  "event Harvest(address indexed caller, uint256 rewards, uint256 fee)",
  "event Invested(uint256 assets)",
  "event StrategySet(address indexed previousStrategy, address indexed newStrategy)",
]);

export const sharesAbi = parseAbi([
  "function balanceOf(address owner) view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function decimals() view returns (uint8)",
]);

export const assetAbi = parseAbi([
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function balanceOf(address owner) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
]);

export const strategyAbi = parseAbi([
  "function totalAssets() view returns (uint256)",
]);

const rawVault = (import.meta.env.VITE_VAULT_ADDRESS || "").trim();
const parsedChainId = Number(import.meta.env.VITE_CHAIN_ID || 96);
const parsedPrice = Number(import.meta.env.VITE_LP_USD_PRICE);
const parsedLookback = Number(import.meta.env.VITE_LOG_LOOKBACK_BLOCKS || 50000);

export const vaultConfig = {
  chainId: Number.isFinite(parsedChainId) ? parsedChainId : 96,
  rpcUrl: import.meta.env.VITE_RPC_URL || "https://rpc.kubchain.io",
  vaultAddress: /^0x[a-fA-F0-9]{40}$/.test(rawVault)
    ? (rawVault as Address)
    : null,
  lpUsdPrice:
    Number.isFinite(parsedPrice) && parsedPrice > 0 ? parsedPrice : null,
  lookbackBlocks: BigInt(
    Math.max(1000, Number.isFinite(parsedLookback) ? parsedLookback : 50000),
  ),
  isDemo:
    !/^0x[a-fA-F0-9]{40}$/.test(rawVault) ||
    import.meta.env.VITE_DEMO === "true",
  name: import.meta.env.VITE_VAULT_NAME || "KKUB–USDT Vault",
  protocolName: import.meta.env.VITE_PROTOCOL_NAME || "Diamond Finance",
  assetSymbol: import.meta.env.VITE_ASSET_SYMBOL || "KKUB–USDT LP",
};

export type ActivityType = "deposit" | "withdraw" | "harvest";

export interface ActivityItem {
  id: string;
  type: ActivityType;
  address: string;
  assets?: number;
  shares?: number;
  rewards?: number;
  fee?: number;
  timestamp: number;
  txHash: string;
}

export interface HistoryPoint {
  timestamp: number;
  tvl: number;
  sharePrice: number;
  apy: number | null;
}

export interface UserPosition {
  shares: number;
  assets: number;
  assetBalance: number;
  allowance: number;
}

export interface VaultSnapshot {
  mode: "demo" | "live";
  name: string;
  protocol: string;
  assetSymbol: string;
  assetDecimals: number;
  underlyingAddress: Address | null;
  tvl: number;
  tvlUsd: number | null;
  apy: number | null;
  sharePrice: number;
  totalShares: number;
  pendingYield: number;
  harvestCount: number;
  depositors: number;
  paused: boolean;
  strategyAddress: Address | null;
  strategyAssets: number;
  harvestFeeBps: number;
  lastHarvestAt: number | null;
  history: HistoryPoint[];
  activity: ActivityItem[];
  user: UserPosition | null;
}
