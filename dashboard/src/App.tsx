import {
  Activity,
  ArrowUpRight,
  Coins,
  Info,
  Layers,
  Percent,
  ShieldAlert,
  Sparkles,
  Vault,
} from "lucide-react";
import { explorerAddressUrl } from "./lib/chains";
import { formatCompact, formatNumber, formatPercent, formatSharePrice, formatUsd, shortAddress } from "./lib/format";
import { vaultConfig } from "./lib/vault";
import { useVaultData } from "./hooks/useVaultData";
import { ActivityTable } from "./components/ActivityTable";
import { PerformanceChart } from "./components/PerformanceChart";
import { StatCard } from "./components/StatCard";
import { StrategyCard } from "./components/StrategyCard";
import { TopNav } from "./components/TopNav";
import { VaultActions } from "./components/VaultActions";

const REPO_URL = "https://github.com/zuhdev/KubYield";

export function App() {
  const { snapshot, isLoading, isError, eventsError } = useVaultData();

  if (!snapshot && isLoading) {
    return (
      <div className="app">
        <TopNav demo={vaultConfig.isDemo} />
        <main className="page">
          <div className="skeleton skeleton--head" />
          <div className="skeleton-grid">
            {Array.from({ length: 4 }).map((_, index) => (
              <div className="skeleton skeleton--stat" key={index} />
            ))}
          </div>
          <div className="content-grid">
            <div className="skeleton skeleton--chart" />
            <div className="skeleton skeleton--panel" />
          </div>
        </main>
      </div>
    );
  }

  if (!snapshot) {
    return (
      <div className="app">
        <TopNav demo={vaultConfig.isDemo} />
        <main className="page">
          <div className="card error-card">
            <Info size={20} />
            <div>
              <h2>Vault data unavailable</h2>
              <p>
                {isError
                  ? "The configured RPC or vault address could not be read. Check VITE_RPC_URL and VITE_VAULT_ADDRESS."
                  : "Set VITE_VAULT_ADDRESS to connect a deployed vault, or leave it empty for preview mode."}
              </p>
            </div>
          </div>
        </main>
      </div>
    );
  }

  const thirtyDaysAgo = Date.now() - 30 * 86_400_000;
  const baseline =
    snapshot.history.find((point) => point.timestamp >= thirtyDaysAgo) ??
    snapshot.history[0];
  const tvlTrend =
    baseline && baseline.tvl > 0
      ? ((snapshot.tvl - baseline.tvl) / baseline.tvl) * 100
      : null;
  const vaultAddress = vaultConfig.vaultAddress;

  return (
    <div className="app" id="top">
      <div className="backdrop" aria-hidden="true">
        <span className="backdrop__glow backdrop__glow--lime" />
        <span className="backdrop__glow backdrop__glow--blue" />
        <span className="backdrop__grid" />
      </div>

      <TopNav demo={snapshot.mode === "demo"} />

      <main className="page">
        <div className="breadcrumbs">
          <span>Earn</span>
          <span className="breadcrumbs__sep">/</span>
          <span>Vaults</span>
          <span className="breadcrumbs__sep">/</span>
          <strong>{snapshot.name.replace(" Vault", "")}</strong>
        </div>

        <section className="vault-head" id="vault">
          <div className="vault-head__left">
            <div className="token-pair" aria-hidden="true">
              <span className="token token--one">K</span>
              <span className="token token--two">U</span>
            </div>
            <div>
              <div className="vault-title-row">
                <h1>{snapshot.name}</h1>
                <span className="pill pill--green">
                  <Sparkles size={12} />
                  Auto-compound
                </span>
                <span className="pill pill--blue">KAP-20 shares</span>
                <span className="pill pill--amber" title="Contracts have not been independently audited">
                  <ShieldAlert size={12} />
                  Unaudited
                </span>
              </div>
              <p className="vault-subtitle">
                Auto-compounding {snapshot.assetSymbol} liquidity on{" "}
                <span className="text-strong">{snapshot.protocol}</span>. Rewards
                are claimed, swapped, and restaked automatically.
              </p>
            </div>
          </div>

          <div className="vault-head__right">
            <span className="vault-status">
              <span
                className={`dot ${
                  snapshot.mode === "demo" || snapshot.paused
                    ? "dot--amber"
                    : "dot--green"
                }`}
              />
              {snapshot.mode === "demo"
                ? "Preview"
                : snapshot.paused
                  ? "Paused"
                  : "Live"}
            </span>
            {vaultAddress ? (
              <a
                className="vault-contract mono"
                href={explorerAddressUrl(vaultConfig.chainId, vaultAddress)}
                target="_blank"
                rel="noreferrer"
              >
                Vault {shortAddress(vaultAddress)}
                <ArrowUpRight size={12} />
              </a>
            ) : (
              <span className="vault-contract vault-contract--muted">
                Preview deployment
              </span>
            )}
          </div>
        </section>

        <div className="stats-grid">
          <StatCard
            label="Total value locked"
            value={
              snapshot.tvlUsd !== null
                ? formatUsd(snapshot.tvlUsd)
                : `${formatCompact(snapshot.tvl)} LP`
            }
            sub="LP principal + strategy"
            icon={<Layers size={17} />}
            trend={tvlTrend}
            accent
          />
          <StatCard
            label="Est. APY"
            value={formatPercent(snapshot.apy)}
            sub={snapshot.mode === "live" ? "Trailing harvests" : "30-day trailing"}
            icon={<Percent size={17} />}
          />
          <StatCard
            label="Share price"
            value={`${formatSharePrice(snapshot.sharePrice)} LP`}
            sub="Redeemable per share"
            icon={<Coins size={17} />}
          />
          <StatCard
            label="Harvests"
            value={formatNumber(snapshot.harvestCount, 0)}
            sub={snapshot.mode === "live" ? "Indexed events" : "Last 30 days"}
            icon={<Activity size={17} />}
          />
        </div>

        <div className="content-grid">
          <div className="content-main">
            <PerformanceChart snapshot={snapshot} />
            <ActivityTable snapshot={snapshot} eventsError={eventsError} />
          </div>
          <aside className="content-side" aria-label="Vault actions">
            <VaultActions snapshot={snapshot} />
            <StrategyCard snapshot={snapshot} />
          </aside>
        </div>

        <section className="vault-facts" aria-label="Vault details">
          <div>
            <span>Underlying asset</span>
            <strong>{snapshot.assetSymbol}</strong>
          </div>
          <div>
            <span>Receipt token</span>
            <strong>KAP-20 shares</strong>
          </div>
          <div>
            <span>Harvest model</span>
            <strong>Permissionless · 5% caller fee</strong>
          </div>
          <div>
            <span>Withdrawals</span>
            <strong>Always available</strong>
          </div>
          <div>
            <span>Vault standard</span>
            <strong>ERC-4626-style</strong>
          </div>
        </section>
      </main>

      <footer className="footer">
        <div className="footer__inner">
          <div className="footer__brand">
            <span className="footer__mark">
              <Vault size={16} />
            </span>
            <div>
              <strong>KubYield</strong>
              <p>Auto-compounding liquidity for KUB Chain.</p>
            </div>
          </div>
          <div className="footer__links">
            <a href={REPO_URL} target="_blank" rel="noreferrer">
              GitHub
            </a>
            <a href={`${REPO_URL}/blob/main/WHITEPAPER.md`} target="_blank" rel="noreferrer">
              Whitepaper
            </a>
            <a
              href={vaultAddress ? explorerAddressUrl(vaultConfig.chainId, vaultAddress) : "https://kubscan.com"}
              target="_blank"
              rel="noreferrer"
            >
              {vaultAddress ? "Explorer" : "KUB Scan"}
            </a>
          </div>
        </div>
        <p className="footer__disclaimer">
          Experimental software. Contracts have not been independently audited.
          APY is an estimate, not a promise. Use at your own risk.
        </p>
      </footer>
    </div>
  );
}
