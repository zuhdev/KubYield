import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import {
  useAccount,
  useConnect,
  usePublicClient,
  useSwitchChain,
  useWriteContract,
} from "wagmi";
import { BaseError } from "viem";
import {
  ArrowUpRight,
  Gauge,
  Loader2,
  Sparkles,
  TriangleAlert,
  Zap,
} from "lucide-react";
import { explorerAddressUrl, explorerTxUrl } from "../lib/chains";
import { formatAmount, formatPercent, shortAddress, timeAgo } from "../lib/format";
import { vaultAbi, vaultConfig, type VaultSnapshot } from "../lib/vault";

export function StrategyCard({ snapshot }: { snapshot: VaultSnapshot }) {
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{
    kind: "ok" | "error";
    text: string;
    hash?: string;
  } | null>(null);

  const { isConnected, chainId: walletChainId } = useAccount();
  const { connectAsync, connectors } = useConnect();
  const { switchChainAsync } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();
  const publicClient = usePublicClient({ chainId: vaultConfig.chainId });
  const queryClient = useQueryClient();

  const isDemo = snapshot.mode === "demo";
  const isWrongNetwork = isConnected && walletChainId !== vaultConfig.chainId;
  const hasStrategy = Boolean(snapshot.strategyAddress);
  const pending = snapshot.pendingYield;
  const callerFee = (pending * snapshot.harvestFeeBps) / 10_000;
  const allocation =
    snapshot.tvl > 0 ? (snapshot.strategyAssets / snapshot.tvl) * 100 : 0;

  const label = (() => {
    if (isDemo) return "Preview only";
    if (!isConnected) return "Connect to harvest";
    if (isWrongNetwork) return "Switch network";
    if (busy) return "Harvesting…";
    if (!hasStrategy) return "No strategy";
    if (pending <= 0) return "Nothing to harvest";
    return "Harvest";
  })();

  async function handleHarvest() {
    setMessage(null);

    if (isDemo) {
      setMessage({
        kind: "error",
        text: "Preview mode: configure a live vault to harvest.",
      });
      return;
    }

    if (!isConnected) {
      const connector =
        connectors.find((item) => item.id === "injected") ?? connectors[0];
      if (!connector) {
        setMessage({ kind: "error", text: "No browser wallet detected." });
        return;
      }
      try {
        await connectAsync({ connector });
      } catch (cause) {
        setMessage({ kind: "error", text: errorMessage(cause) });
      }
      return;
    }

    if (isWrongNetwork) {
      try {
        await switchChainAsync({ chainId: vaultConfig.chainId });
      } catch (cause) {
        setMessage({ kind: "error", text: errorMessage(cause) });
      }
      return;
    }

    if (!vaultConfig.vaultAddress || !publicClient) return;

    try {
      setBusy(true);
      const hash = await writeContractAsync({
        address: vaultConfig.vaultAddress,
        abi: vaultAbi,
        functionName: "harvest",
        chainId: vaultConfig.chainId,
      });
      await publicClient.waitForTransactionReceipt({ hash });
      setMessage({ kind: "ok", text: "Harvest confirmed.", hash });
      await queryClient.invalidateQueries();
    } catch (cause) {
      setMessage({ kind: "error", text: errorMessage(cause) });
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="card strategy-card">
      <div className="card__head">
        <div>
          <div className="eyebrow">
            <Gauge size={13} />
            Strategy
          </div>
          <h2 className="card__title card__title--sm">{snapshot.protocol}</h2>
        </div>
        <span className={`pill ${hasStrategy ? "pill--green" : "pill--muted"}`}>
          <span className={`dot ${hasStrategy ? "dot--green" : "dot--muted"}`} />
          {hasStrategy ? "Active" : "Not set"}
        </span>
      </div>

      <div className="strategy-stats">
        <div>
          <span>Allocated</span>
          <strong>{formatPercent(allocation, 1)}</strong>
        </div>
        <div>
          <span>Strategy assets</span>
          <strong>{formatAmount(snapshot.strategyAssets, 2)} LP</strong>
        </div>
        <div>
          <span>Pending yield</span>
          <strong className={pending > 0 ? "text-lime" : ""}>
            {formatAmount(pending, 2)} LP
          </strong>
        </div>
      </div>

      <div className="allocation">
        <span className="allocation__bar">
          <span
            className="allocation__fill"
            style={{ width: `${Math.max(2, Math.min(100, allocation))}%` }}
          />
        </span>
        <span className="allocation__labels">
          <span>Idle {formatPercent(100 - allocation, 1)}</span>
          <span>Deployed {formatPercent(allocation, 1)}</span>
        </span>
      </div>

      <div className="strategy-meta">
        <div>
          <span>Caller fee</span>
          <strong>{(snapshot.harvestFeeBps / 100).toFixed(1)}%</strong>
        </div>
        <div>
          <span>Est. fee</span>
          <strong>{formatAmount(callerFee, 4)} LP</strong>
        </div>
        <div>
          <span>Last harvest</span>
          <strong>
            {snapshot.lastHarvestAt
              ? timeAgo(snapshot.lastHarvestAt)
              : "No harvests yet"}
          </strong>
        </div>
      </div>

      <button
        className="btn btn--secondary btn--block"
        onClick={handleHarvest}
        disabled={
          isDemo ||
          busy ||
          (isConnected &&
            !isWrongNetwork &&
            (!hasStrategy || pending <= 0))
        }
        type="button"
      >
        {busy ? <Loader2 size={15} className="spin" /> : <Zap size={15} />}
        {label}
      </button>

      {message ? (
        <div
          className={`notice notice--${
            message.kind === "ok" ? "success" : "error"
          }`}
        >
          {message.kind === "ok" ? <Sparkles size={14} /> : <TriangleAlert size={14} />}
          <span>{message.text}</span>
          {message.hash ? (
            <a
              className="notice__link"
              href={explorerTxUrl(vaultConfig.chainId, message.hash)}
              target="_blank"
              rel="noreferrer"
            >
              {shortAddress(message.hash)}
            </a>
          ) : null}
        </div>
      ) : null}

      {snapshot.strategyAddress ? (
        <a
          className="contract-link"
          href={explorerAddressUrl(vaultConfig.chainId, snapshot.strategyAddress)}
          target="_blank"
          rel="noreferrer"
        >
          Strategy {shortAddress(snapshot.strategyAddress)}
          <ArrowUpRight size={12} />
        </a>
      ) : (
        <p className="strategy-empty">
          No strategy is configured. Deposits remain idle until the owner sets
          one.
        </p>
      )}
    </section>
  );
}

function errorMessage(cause: unknown) {
  if (cause instanceof BaseError) {
    return cause.shortMessage || cause.message;
  }
  if (cause instanceof Error) return cause.message.split("\n")[0];
  return "Transaction failed.";
}
