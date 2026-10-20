import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useAccount, usePublicClient, useReadContract } from "wagmi";
import {
  decodeEventLog,
  formatUnits,
  type Address,
  type Log,
} from "viem";
import {
  assetAbi,
  sharesAbi,
  strategyAbi,
  vaultAbi,
  vaultConfig,
  type ActivityItem,
  type HistoryPoint,
  type VaultSnapshot,
} from "../lib/vault";
import { demoSnapshot } from "../lib/demo";
import { chainForId } from "../lib/chains";

const SHARE_UNIT = 10n ** 18n;
const DEFAULT_DECIMALS = 18;

type DecodedVaultEvent =
  | {
      type: "deposit";
      blockNumber: bigint;
      txHash: string;
      address: string;
      assets: bigint;
      shares: bigint;
    }
  | {
      type: "withdraw";
      blockNumber: bigint;
      txHash: string;
      address: string;
      assets: bigint;
      shares: bigint;
    }
  | {
      type: "harvest";
      blockNumber: bigint;
      txHash: string;
      address: string;
      rewards: bigint;
      fee: bigint;
    };

function asNumber(value: bigint | undefined, decimals = DEFAULT_DECIMALS) {
  if (value === undefined) return 0;
  return Number(formatUnits(value, decimals));
}

function decodeLogs(logs: Log[]): DecodedVaultEvent[] {
  const events: DecodedVaultEvent[] = [];

  for (const log of logs) {
    try {
      const decoded = decodeEventLog({
        abi: vaultAbi,
        data: log.data,
        topics: log.topics,
      });

      if (decoded.eventName === "Deposit") {
        const args = decoded.args as unknown as {
          caller: Address;
          receiver: Address;
          assets: bigint;
          shares: bigint;
        };
        events.push({
          type: "deposit",
          blockNumber: log.blockNumber ?? 0n,
          txHash: log.transactionHash ?? "",
          address: args.receiver,
          assets: args.assets,
          shares: args.shares,
        });
      }

      if (decoded.eventName === "Withdraw") {
        const args = decoded.args as unknown as {
          caller: Address;
          receiver: Address;
          assets: bigint;
          shares: bigint;
        };
        events.push({
          type: "withdraw",
          blockNumber: log.blockNumber ?? 0n,
          txHash: log.transactionHash ?? "",
          address: args.receiver,
          assets: args.assets,
          shares: args.shares,
        });
      }

      if (decoded.eventName === "Harvest") {
        const args = decoded.args as unknown as {
          caller: Address;
          rewards: bigint;
          fee: bigint;
        };
        events.push({
          type: "harvest",
          blockNumber: log.blockNumber ?? 0n,
          txHash: log.transactionHash ?? "",
          address: args.caller,
          rewards: args.rewards,
          fee: args.fee,
        });
      }
    } catch {
      continue;
    }
  }

  return events;
}

async function fetchEventData(
  publicClient: NonNullable<ReturnType<typeof usePublicClient>>,
  vault: Address,
  lookbackBlocks: bigint,
  decimals: number,
  currentAssets: bigint,
  currentSharePrice: number,
) {
  const latestBlock = await publicClient.getBlockNumber();
  const fromBlock =
    latestBlock > lookbackBlocks ? latestBlock - lookbackBlocks : 0n;
  const chunkSize = 5_000n;
  const ranges: Array<[bigint, bigint]> = [];

  for (let start = fromBlock; start <= latestBlock; start += chunkSize) {
    const end =
      start + chunkSize - 1n > latestBlock
        ? latestBlock
        : start + chunkSize - 1n;
    ranges.push([start, end]);
  }

  const logChunks = await Promise.all(
    ranges.map(([start, end]) =>
      publicClient.getLogs({
        address: vault,
        fromBlock: start,
        toBlock: end,
      }),
    ),
  );

  const events = decodeLogs(logChunks.flat()).sort((a, b) =>
    a.blockNumber < b.blockNumber ? -1 : a.blockNumber > b.blockNumber ? 1 : 0,
  );

  const uniqueBlocks = [
    ...new Set(events.map((event) => event.blockNumber.toString())),
  ].slice(-80);

  const blockTimes = new Map<string, number>();
  await Promise.all(
    uniqueBlocks.map(async (block) => {
      try {
        const data = await publicClient.getBlock({
          blockNumber: BigInt(block),
        });
        blockTimes.set(block, Number(data.timestamp) * 1000);
      } catch {
        blockTimes.set(block, 0);
      }
    }),
  );

  const timestampFor = (blockNumber: bigint) =>
    blockTimes.get(blockNumber.toString()) || 0;

  const activity: ActivityItem[] = events
    .slice(-12)
    .reverse()
    .map((event, index) => {
      if (event.type === "harvest") {
        return {
          id: `${event.txHash}-${index}`,
          type: "harvest",
          address: event.address,
          rewards: asNumber(event.rewards, decimals),
          fee: asNumber(event.fee, decimals),
          timestamp: timestampFor(event.blockNumber),
          txHash: event.txHash,
        };
      }

      return {
        id: `${event.txHash}-${index}`,
        type: event.type,
        address: event.address,
        assets: asNumber(event.assets, decimals),
        shares: asNumber(event.shares, decimals),
        timestamp: timestampFor(event.blockNumber),
        txHash: event.txHash,
      };
    });

  const harvestEvents = events.filter((event) => event.type === "harvest");
  const depositEvents = events.filter((event) => event.type === "deposit");
  const depositors = new Set(depositEvents.map((event) => event.address)).size;

  const lastHarvest = harvestEvents[harvestEvents.length - 1];
  const firstHarvest = harvestEvents[0];
  const lastHarvestAt = lastHarvest ? timestampFor(lastHarvest.blockNumber) : null;

  let apy: number | null = null;
  if (firstHarvest && lastHarvest) {
    const rewards = harvestEvents.reduce(
      (total, event) => total + event.rewards,
      0n,
    );
    const spanMs =
      timestampFor(lastHarvest.blockNumber) -
      timestampFor(firstHarvest.blockNumber);
    const currentTvl = asNumber(currentAssets, decimals);
    if (spanMs > 60_000 && currentTvl > 0) {
      const yearMs = 365 * 24 * 60 * 60 * 1000;
      apy = Math.min(
        500,
        (asNumber(rewards, decimals) / currentTvl) * (yearMs / spanMs) * 100,
      );
    }
  }

  const history: HistoryPoint[] = [];
  let value = currentAssets;

  history.push({
    timestamp: Date.now(),
    tvl: asNumber(value, decimals),
    sharePrice: currentSharePrice,
    apy,
  });

  for (let index = events.length - 1; index >= 0; index -= 1) {
    const event = events[index];
    if (event.type === "deposit") {
      value = value > event.assets ? value - event.assets : 0n;
    } else if (event.type === "withdraw") {
      value += event.assets;
    } else {
      value += event.fee;
    }

    const timestamp = timestampFor(event.blockNumber);
    if (!timestamp) continue;

    const tvl = asNumber(value, decimals);
    history.push({
      timestamp,
      tvl,
      sharePrice:
        currentTvlForRatio(currentAssets, decimals) > 0
          ? currentSharePrice *
            (tvl / currentTvlForRatio(currentAssets, decimals))
          : currentSharePrice,
      apy,
    });
  }

  history.sort((a, b) => a.timestamp - b.timestamp);

  return {
    activity,
    history,
    harvestCount: harvestEvents.length,
    depositors,
    lastHarvestAt,
    apy,
  };
}

function currentTvlForRatio(assets: bigint, decimals: number) {
  return asNumber(assets, decimals);
}

export function useVaultData() {
  const { address: account } = useAccount();
  const queryClient = useQueryClient();
  const enabled = !vaultConfig.isDemo && Boolean(vaultConfig.vaultAddress);
  const chainId = vaultConfig.chainId;
  const vault = vaultConfig.vaultAddress ?? undefined;
  const publicClient = usePublicClient({ chainId });

  const totalAssetsQuery = useReadContract({
    address: vault,
    abi: vaultAbi,
    functionName: "totalAssets",
    chainId,
    query: { enabled, refetchInterval: 15_000 },
  });

  const accountedAssetsQuery = useReadContract({
    address: vault,
    abi: vaultAbi,
    functionName: "accountedAssets",
    chainId,
    query: { enabled, refetchInterval: 15_000 },
  });

  const underlyingQuery = useReadContract({
    address: vault,
    abi: vaultAbi,
    functionName: "underlying",
    chainId,
    query: { enabled },
  });

  const sharesTokenQuery = useReadContract({
    address: vault,
    abi: vaultAbi,
    functionName: "sharesToken",
    chainId,
    query: { enabled },
  });

  const strategyQuery = useReadContract({
    address: vault,
    abi: vaultAbi,
    functionName: "strategy",
    chainId,
    query: { enabled },
  });

  const pausedQuery = useReadContract({
    address: vault,
    abi: vaultAbi,
    functionName: "paused",
    chainId,
    query: { enabled },
  });

  const harvestFeeQuery = useReadContract({
    address: vault,
    abi: vaultAbi,
    functionName: "HARVEST_FEE_BPS",
    chainId,
    query: { enabled },
  });

  const sharePriceQuery = useReadContract({
    address: vault,
    abi: vaultAbi,
    functionName: "previewRedeem",
    args: [SHARE_UNIT],
    chainId,
    query: { enabled },
  });

  const underlying = underlyingQuery.data;
  const sharesToken = sharesTokenQuery.data;
  const strategy = strategyQuery.data;

  const assetDecimalsQuery = useReadContract({
    address: underlying,
    abi: assetAbi,
    functionName: "decimals",
    chainId,
    query: { enabled: enabled && Boolean(underlying) },
  });

  const assetSymbolQuery = useReadContract({
    address: underlying,
    abi: assetAbi,
    functionName: "symbol",
    chainId,
    query: { enabled: enabled && Boolean(underlying) },
  });

  const totalSupplyQuery = useReadContract({
    address: sharesToken,
    abi: sharesAbi,
    functionName: "totalSupply",
    chainId,
    query: { enabled: enabled && Boolean(sharesToken) },
  });

  const userSharesQuery = useReadContract({
    address: sharesToken,
    abi: sharesAbi,
    functionName: "balanceOf",
    args: account ? [account] : undefined,
    chainId,
    query: {
      enabled: enabled && Boolean(sharesToken) && Boolean(account),
      refetchInterval: 15_000,
    },
  });

  const userAssetsQuery = useReadContract({
    address: vault,
    abi: vaultAbi,
    functionName: "previewRedeem",
    args: userSharesQuery.data ? [userSharesQuery.data] : undefined,
    chainId,
    query: {
      enabled: enabled && Boolean(vault) && userSharesQuery.data !== undefined,
      refetchInterval: 15_000,
    },
  });

  const userAssetBalanceQuery = useReadContract({
    address: underlying,
    abi: assetAbi,
    functionName: "balanceOf",
    args: account ? [account] : undefined,
    chainId,
    query: {
      enabled: enabled && Boolean(underlying) && Boolean(account),
      refetchInterval: 15_000,
    },
  });

  const allowanceQuery = useReadContract({
    address: underlying,
    abi: assetAbi,
    functionName: "allowance",
    args: account && vault ? [account, vault] : undefined,
    chainId,
    query: {
      enabled: enabled && Boolean(underlying) && Boolean(account) && Boolean(vault),
      refetchInterval: 15_000,
    },
  });

  const strategyAssetsQuery = useReadContract({
    address: strategy,
    abi: strategyAbi,
    functionName: "totalAssets",
    chainId,
    query: {
      enabled: enabled && Boolean(strategy) && strategy !== "0x0000000000000000000000000000000000000000",
      refetchInterval: 15_000,
    },
  });

  const decimals = assetDecimalsQuery.data ?? DEFAULT_DECIMALS;
  const totalAssets = totalAssetsQuery.data;
  const sharePrice = sharePriceQuery.data
    ? asNumber(sharePriceQuery.data, decimals)
    : 0;

  const eventsQuery = useQuery({
    queryKey: [
      "vault-events",
      vault,
      chainId,
      vaultConfig.lookbackBlocks.toString(),
      decimals,
    ],
    enabled: enabled && Boolean(vault) && Boolean(publicClient) && totalAssets !== undefined,
    staleTime: 20_000,
    refetchInterval: 30_000,
    queryFn: async () => {
      if (!publicClient || !vault || totalAssets === undefined) {
        throw new Error("Vault is not configured");
      }
      return fetchEventData(
        publicClient,
        vault,
        vaultConfig.lookbackBlocks,
        decimals,
        totalAssets,
        sharePrice,
      );
    },
  });

  let snapshot: VaultSnapshot | null = null;

  if (vaultConfig.isDemo) {
    snapshot = {
      ...demoSnapshot,
      user: account ? demoSnapshot.user : null,
    };
  } else if (
    enabled &&
    vault &&
    totalAssets !== undefined
  ) {
    const tvl = asNumber(totalAssets, decimals);
    const pendingYield = totalAssets > (accountedAssetsQuery.data ?? 0n)
      ? asNumber(totalAssets - (accountedAssetsQuery.data ?? 0n), decimals)
      : 0;
    const events = eventsQuery.data;

    snapshot = {
      mode: "live",
      name: vaultConfig.name,
      protocol: vaultConfig.protocolName,
      assetSymbol: assetSymbolQuery.data || vaultConfig.assetSymbol,
      assetDecimals: decimals,
      underlyingAddress: underlying ?? null,
      tvl,
      tvlUsd: vaultConfig.lpUsdPrice ? tvl * vaultConfig.lpUsdPrice : null,
      apy: events?.apy ?? null,
      sharePrice,
      totalShares: asNumber(totalSupplyQuery.data, decimals),
      pendingYield,
      harvestCount: events?.harvestCount ?? 0,
      depositors: events?.depositors ?? 0,
      paused: pausedQuery.data ?? false,
      strategyAddress:
        strategy && strategy !== "0x0000000000000000000000000000000000000000"
          ? strategy
          : null,
      strategyAssets: asNumber(strategyAssetsQuery.data, decimals),
      harvestFeeBps: Number(harvestFeeQuery.data ?? 500n),
      lastHarvestAt: events?.lastHarvestAt ?? null,
      history:
        events?.history.length && events.history.length > 1
          ? events.history
          : [
              {
                timestamp: Date.now(),
                tvl,
                sharePrice,
                apy: events?.apy ?? null,
              },
            ],
      activity: events?.activity ?? [],
      user: account
        ? {
            shares: asNumber(userSharesQuery.data, decimals),
            assets: asNumber(userAssetsQuery.data, decimals),
            assetBalance: asNumber(userAssetBalanceQuery.data, decimals),
            allowance: asNumber(allowanceQuery.data, decimals),
          }
        : null,
    };
  }

  const isLoading =
    !vaultConfig.isDemo &&
    enabled &&
    totalAssetsQuery.isLoading;
  const isError = !vaultConfig.isDemo && enabled && totalAssetsQuery.isError;

  return {
    snapshot,
    isLoading,
    isError,
    eventsError: eventsQuery.isError,
    refetch: () => queryClient.invalidateQueries(),
    chain: chainForId(chainId),
  };
}
