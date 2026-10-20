import { vaultConfig, type ActivityItem, type HistoryPoint, type VaultSnapshot } from "./vault";

const DAY = 86_400_000;
const now = Date.now();

function buildHistory(): HistoryPoint[] {
  return Array.from({ length: 90 }, (_, index) => {
    const progress = index / 89;
    const timestamp = now - (89 - index) * DAY;
    const tvl =
      74_000 +
      progress * 54_500 +
      Math.sin(index / 5.2) * 3_900 +
      Math.sin(index / 11.4) * 1_700;
    const sharePrice =
      1 +
      progress * 0.0421 +
      Math.sin(index / 9.2) * 0.0016 +
      Math.sin(index / 21.7) * 0.0008;
    const apy = 15.6 + Math.sin(index / 7.1) * 2.4 + progress * 1.7;
    return {
      timestamp,
      tvl,
      sharePrice,
      apy: Number(apy.toFixed(2)),
    };
  });
}

const history = buildHistory();
const latest = history[history.length - 1];

const addresses = [
  "0x7A3f2F1B6D8E4C0A9b5F8e2D1c6B4a3E9f0D8c21",
  "0x2C9a7E4b1D8f6A3c5B0e9F2d7A4c1E8b6D3f0A52",
  "0x9E1d4C7b2A5f8D0e3B6c9F1a4D7e2C5b8A0f3D64",
  "0x5B8e2D6a9C1f4A7b0E3d8F5c2A9e6B1d4C7f0A95",
  "0x1F4c8A2e6D9b3F0a7C5e1B8d4A6f2E9c3B0d7A46",
  "0x8D2b5F9a1C4e7B0d3A6f8C2e5D9a1B4c7E0f6D83",
  "0x3A7e1C5b8D2f6A9c4E0b7F1d5C8a2B6e9D3f0A74",
  "0x6E0a3D7c1B5f8A2e9C4d6F0b3A7e1D5c8B2f9A45",
];

const activity: ActivityItem[] = [
  {
    id: "demo-1",
    type: "harvest",
    address: addresses[0],
    rewards: 84.21,
    fee: 4.21,
    timestamp: now - 12 * 60_000,
    txHash:
      "0x6a1d2b7f9c4e8a0d3b5f1c7e9a2d4b6f8c0e1a3d5b7f9c2e4a6d8b0f1c3e5a7d",
  },
  {
    id: "demo-2",
    type: "deposit",
    address: addresses[1],
    assets: 4_200,
    shares: 4_031.8,
    timestamp: now - 38 * 60_000,
    txHash:
      "0x9b3e5a7c1d4f6b8a0c2e4f6a8b0d2f4c6e8a0b2d4f6c8e0a2b4d6f8c0e2a4b6d",
  },
  {
    id: "demo-3",
    type: "withdraw",
    address: addresses[2],
    assets: 912.44,
    shares: 876.1,
    timestamp: now - 63 * 60_000,
    txHash:
      "0x2d4f6a8c0e2b4d6f8a0c2e4f6a8b0d2f4c6e8a0b2d4f6c8e0a2b4d6f8c0e2a4f",
  },
  {
    id: "demo-4",
    type: "deposit",
    address: addresses[3],
    assets: 12_500,
    shares: 11_999.2,
    timestamp: now - 2.4 * 3_600_000,
    txHash:
      "0x8c0e2a4b6d8f0a2c4e6b8d0f2a4c6e8b0d2f4a6c8e0b2d4f6a8c0e2b4d6f8a0c",
  },
  {
    id: "demo-5",
    type: "harvest",
    address: addresses[4],
    rewards: 61.84,
    fee: 3.09,
    timestamp: now - 3.1 * 3_600_000,
    txHash:
      "0x4e6b8d0f2a4c6e8b0d2f4a6c8e0b2d4f6a8c0e2b4d6f8a0c2e4b6d8f0a2c4e6b",
  },
  {
    id: "demo-6",
    type: "deposit",
    address: addresses[5],
    assets: 2_750,
    shares: 2_639.8,
    timestamp: now - 5.2 * 3_600_000,
    txHash:
      "0x0a2c4e6b8d0f2a4c6e8b0d2f4a6c8e0b2d4f6a8c0e2b4d6f8a0c2e4b6d8f0a2c",
  },
  {
    id: "demo-7",
    type: "withdraw",
    address: addresses[6],
    assets: 1_480.2,
    shares: 1_420.9,
    timestamp: now - 8.6 * 3_600_000,
    txHash:
      "0x6e8b0d2f4a6c8e0b2d4f6a8c0e2b4d6f8a0c2e4b6d8f0a2c4e6b8d0f2a4c6e8b",
  },
  {
    id: "demo-8",
    type: "harvest",
    address: addresses[7],
    rewards: 97.32,
    fee: 4.87,
    timestamp: now - 13.4 * 3_600_000,
    txHash:
      "0x2f4a6c8e0b2d4f6a8c0e2b4d6f8a0c2e4b6d8f0a2c4e6b8d0f2a4c6e8b0d2f4a",
  },
];

export const demoSnapshot: VaultSnapshot = {
  mode: "demo",
  name: vaultConfig.name,
  protocol: vaultConfig.protocolName,
  assetSymbol: vaultConfig.assetSymbol,
  assetDecimals: 18,
  underlyingAddress: "0x4de09F9E7282C1E66ED13ed930942E7fAb9915E9",
  tvl: latest.tvl,
  tvlUsd: latest.tvl * (vaultConfig.lpUsdPrice ?? 1),
  apy: latest.apy,
  sharePrice: latest.sharePrice,
  totalShares: latest.tvl / latest.sharePrice,
  pendingYield: 1_284.5,
  harvestCount: 286,
  depositors: 412,
  paused: false,
  strategyAddress: "0x7A3f2F1B6D8E4C0A9b5F8e2D1c6B4a3E9f0D8c21",
  strategyAssets: latest.tvl * 0.94,
  harvestFeeBps: 500,
  lastHarvestAt: now - 12 * 60_000,
  history,
  activity,
  user: {
    shares: 1_840.5,
    assets: 1_840.5 * latest.sharePrice,
    assetBalance: 640,
    allowance: 0,
  },
};
