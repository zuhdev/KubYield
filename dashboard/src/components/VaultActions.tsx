import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import {
  useAccount,
  useConnect,
  usePublicClient,
  useSwitchChain,
  useWriteContract,
} from "wagmi";
import { BaseError, parseUnits } from "viem";
import {
  ArrowDownToLine,
  ArrowUpFromLine,
  CheckCircle2,
  ExternalLink,
  Info,
  Loader2,
  ShieldCheck,
  TriangleAlert,
} from "lucide-react";
import { explorerTxUrl } from "../lib/chains";
import { formatAmount, shortAddress } from "../lib/format";
import { assetAbi, vaultAbi, vaultConfig, type VaultSnapshot } from "../lib/vault";

type Tab = "deposit" | "withdraw";
type Phase = "idle" | "approving" | "depositing" | "withdrawing";
type Notice = {
  kind: "success" | "error" | "info";
  text: string;
  hash?: string;
};

export function VaultActions({ snapshot }: { snapshot: VaultSnapshot }) {
  const [tab, setTab] = useState<Tab>("deposit");
  const [amount, setAmount] = useState("");
  const [phase, setPhase] = useState<Phase>("idle");
  const [notice, setNotice] = useState<Notice | null>(null);

  const { isConnected, chainId: walletChainId } = useAccount();
  const { connectAsync, connectors } = useConnect();
  const { switchChainAsync } = useSwitchChain();
  const { writeContractAsync } = useWriteContract();
  const publicClient = usePublicClient({ chainId: vaultConfig.chainId });
  const queryClient = useQueryClient();

  const user = snapshot.user;
  const isDemo = snapshot.mode === "demo";
  const isWrongNetwork =
    isConnected && walletChainId !== vaultConfig.chainId;
  const isBusy = phase !== "idle";
  const paused = snapshot.paused;
  const sharePrice = snapshot.sharePrice || 1;
  const amountNumber = Number(amount) || 0;
  const maxAmount = tab === "deposit" ? user?.assetBalance ?? 0 : user?.shares ?? 0;
  const needsApproval =
    tab === "deposit" &&
    amountNumber > 0 &&
    amountNumber > (user?.allowance ?? 0);
  const estimatedShares = tab === "deposit" ? amountNumber / sharePrice : 0;
  const estimatedAssets = tab === "withdraw" ? amountNumber * sharePrice : 0;
  const invalidAmount = amountNumber <= 0;

  const buttonLabel = (() => {
    if (isDemo) return "Preview only";
    if (!isConnected) return "Connect wallet";
    if (isWrongNetwork) return "Switch to KUB Chain";
    if (paused && tab === "deposit") return "Deposits paused";
    if (phase === "approving") return "Approving…";
    if (phase === "depositing") return "Depositing…";
    if (phase === "withdrawing") return "Withdrawing…";
    if (invalidAmount) return tab === "deposit" ? "Enter amount" : "Enter shares";
    if (needsApproval) return `Approve ${snapshot.assetSymbol}`;
    return tab === "deposit" ? "Deposit" : "Withdraw";
  })();

  const disabled =
    isDemo ||
    isBusy ||
    (isConnected &&
      !isWrongNetwork &&
      (invalidAmount || (paused && tab === "deposit")));

  function handleMax() {
    if (maxAmount <= 0) return;
    setAmount(
      maxAmount
        .toFixed(Math.min(snapshot.assetDecimals, 6))
        .replace(/\.?0+$/, ""),
    );
  }

  async function handleConnect() {
    const connector =
      connectors.find((item) => item.id === "injected") ?? connectors[0];
    if (!connector) {
      setNotice({ kind: "error", text: "No browser wallet detected." });
      return;
    }
    try {
      await connectAsync({ connector });
    } catch (cause) {
      setNotice({ kind: "error", text: errorMessage(cause) });
    }
  }

  async function handleSubmit() {
    setNotice(null);

    if (isDemo) {
      setNotice({
        kind: "info",
        text: "Preview mode: configure VITE_VAULT_ADDRESS to transact.",
      });
      return;
    }

    if (!isConnected) {
      await handleConnect();
      return;
    }

    if (isWrongNetwork) {
      try {
        await switchChainAsync({ chainId: vaultConfig.chainId });
      } catch (cause) {
        setNotice({ kind: "error", text: errorMessage(cause) });
      }
      return;
    }

    if (invalidAmount) return;
    if (paused && tab === "deposit") {
      setNotice({ kind: "error", text: "Deposits are paused." });
      return;
    }
    if (!vaultConfig.vaultAddress || !snapshot.underlyingAddress) {
      setNotice({ kind: "error", text: "Vault is not configured." });
      return;
    }
    if (!publicClient) {
      setNotice({ kind: "error", text: "RPC client is not available." });
      return;
    }

    let parsedAmount: bigint;
    try {
      parsedAmount = parseUnits(amount, snapshot.assetDecimals);
    } catch {
      setNotice({ kind: "error", text: "Invalid amount." });
      return;
    }

    if (parsedAmount === 0n) return;

    if (tab === "deposit" && amountNumber > (user?.assetBalance ?? 0)) {
      setNotice({ kind: "error", text: "Amount exceeds your wallet balance." });
      return;
    }

    if (tab === "withdraw" && amountNumber > (user?.shares ?? 0)) {
      setNotice({ kind: "error", text: "Amount exceeds your share balance." });
      return;
    }

    try {
      if (tab === "deposit" && needsApproval) {
        setPhase("approving");
        const approveHash = await writeContractAsync({
          address: snapshot.underlyingAddress,
          abi: assetAbi,
          functionName: "approve",
          args: [vaultConfig.vaultAddress, parsedAmount],
          chainId: vaultConfig.chainId,
        });
        await publicClient.waitForTransactionReceipt({ hash: approveHash });
      }

      if (tab === "deposit") {
        setPhase("depositing");
        const hash = await writeContractAsync({
          address: vaultConfig.vaultAddress,
          abi: vaultAbi,
          functionName: "deposit",
          args: [parsedAmount],
          chainId: vaultConfig.chainId,
        });
        await publicClient.waitForTransactionReceipt({ hash });
        setNotice({
          kind: "success",
          text: "Deposit confirmed. Your shares are compounding.",
          hash,
        });
        setAmount("");
      } else {
        setPhase("withdrawing");
        const hash = await writeContractAsync({
          address: vaultConfig.vaultAddress,
          abi: vaultAbi,
          functionName: "withdraw",
          args: [parsedAmount],
          chainId: vaultConfig.chainId,
        });
        await publicClient.waitForTransactionReceipt({ hash });
        setNotice({
          kind: "success",
          text: "Withdrawal confirmed. Assets are in your wallet.",
          hash,
        });
        setAmount("");
      }

      await queryClient.invalidateQueries();
    } catch (cause) {
      setNotice({ kind: "error", text: errorMessage(cause) });
    } finally {
      setPhase("idle");
    }
  }

  return (
    <section className="card action-card">
      <div className="segmented segmented--tabs action-card__tabs">
        <button
          className={tab === "deposit" ? "segmented__btn is-active" : "segmented__btn"}
          onClick={() => {
            setTab("deposit");
            setAmount("");
            setNotice(null);
          }}
          type="button"
        >
          <ArrowDownToLine size={15} />
          Deposit
        </button>
        <button
          className={tab === "withdraw" ? "segmented__btn is-active" : "segmented__btn"}
          onClick={() => {
            setTab("withdraw");
            setAmount("");
            setNotice(null);
          }}
          type="button"
        >
          <ArrowUpFromLine size={15} />
          Withdraw
        </button>
      </div>

      {isDemo ? (
        <div className="inline-note inline-note--amber">
          <Info size={14} />
          Preview mode. Deploy a vault and set <code>VITE_VAULT_ADDRESS</code> to transact.
        </div>
      ) : null}

      {paused ? (
        <div className="inline-note inline-note--amber">
          <TriangleAlert size={14} />
          Deposits and harvests are paused. Withdrawals remain open.
        </div>
      ) : null}

      <div className="position-strip">
        <div>
          <span className="position-strip__label">Your position</span>
          <strong className="position-strip__value">
            {isConnected && user
              ? `${formatAmount(user.shares, 2)} shares`
              : "—"}
          </strong>
        </div>
        <div className="position-strip__right">
          <span className="position-strip__label">Redeemable</span>
          <strong className="position-strip__value">
            {isConnected && user
              ? `${formatAmount(user.assets, 2)} LP`
              : "Connect wallet"}
          </strong>
        </div>
      </div>

      <div className="field">
        <div className="field__label">
          <span>{tab === "deposit" ? "Deposit amount" : "Withdraw shares"}</span>
          <span className="field__balance">
            {tab === "deposit" ? "Wallet" : "Available"}:{" "}
            {formatAmount(maxAmount, 4)} {tab === "deposit" ? "LP" : "shares"}
            <button className="max-btn" onClick={handleMax} type="button">
              MAX
            </button>
          </span>
        </div>
        <div className="field__wrap">
          <input
            className="field__input"
            value={amount}
            onChange={(event) => {
              const next = event.target.value.replace(/,/g, "");
              if (/^\d*\.?\d{0,18}$/.test(next)) setAmount(next);
            }}
            placeholder="0.00"
            inputMode="decimal"
            aria-label={tab === "deposit" ? "Deposit amount" : "Withdraw shares"}
          />
          <span className="field__suffix">
            {tab === "deposit" ? "LP" : "shares"}
          </span>
        </div>
      </div>

      <div className="action-summary">
        <div className="action-summary__row">
          <span>You receive</span>
          <strong>
            {tab === "deposit"
              ? `${formatAmount(estimatedShares, 4)} shares`
              : `${formatAmount(estimatedAssets, 4)} LP`}
          </strong>
        </div>
        <div className="action-summary__row">
          <span>Share price</span>
          <strong>{sharePrice.toFixed(4)} LP</strong>
        </div>
        <div className="action-summary__row">
          <span>Harvest fee</span>
          <strong>{(snapshot.harvestFeeBps / 100).toFixed(1)}% to caller</strong>
        </div>
      </div>

      <button
        className="btn btn--primary btn--block"
        onClick={handleSubmit}
        disabled={disabled}
        type="button"
      >
        {isBusy ? <Loader2 size={16} className="spin" /> : null}
        {buttonLabel}
      </button>

      {notice ? (
        <div className={`notice notice--${notice.kind}`}>
          {notice.kind === "success" ? <CheckCircle2 size={15} /> : null}
          {notice.kind === "error" ? <TriangleAlert size={15} /> : null}
          {notice.kind === "info" ? <Info size={15} /> : null}
          <span>{notice.text}</span>
          {notice.hash ? (
            <a
              href={explorerTxUrl(vaultConfig.chainId, notice.hash)}
              target="_blank"
              rel="noreferrer"
              className="notice__link"
            >
              {shortAddress(notice.hash)}
              <ExternalLink size={12} />
            </a>
          ) : null}
        </div>
      ) : null}

      <ul className="action-notes">
        <li>
          <ShieldCheck size={14} />
          Withdrawals stay available while paused.
        </li>
        <li>
          <Info size={14} />
          No deposit or withdrawal fees.
        </li>
      </ul>
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
