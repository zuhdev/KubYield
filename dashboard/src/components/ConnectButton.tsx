import { useEffect, useRef, useState } from "react";
import { useAccount, useConnect, useDisconnect } from "wagmi";
import {
  Check,
  ChevronDown,
  Copy,
  ExternalLink,
  LogOut,
  Wallet,
} from "lucide-react";
import { explorerAddressUrl } from "../lib/chains";
import { shortAddress } from "../lib/format";
import { vaultConfig } from "../lib/vault";

export function ConnectButton() {
  const { address, isConnected, chainId } = useAccount();
  const { connectAsync, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const [open, setOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const wrapper = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function onPointerDown(event: MouseEvent) {
      if (!wrapper.current?.contains(event.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onPointerDown);
    return () => document.removeEventListener("mousedown", onPointerDown);
  }, []);

  async function handleConnect() {
    const connector =
      connectors.find((item) => item.id === "injected") ?? connectors[0];
    if (!connector) {
      setError("No browser wallet detected.");
      return;
    }
    setError(null);
    try {
      await connectAsync({ connector });
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message.split("\n")[0]
          : "Could not connect wallet.",
      );
    }
  }

  async function copyAddress() {
    if (!address) return;
    await navigator.clipboard.writeText(address);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1500);
  }

  if (!isConnected || !address) {
    return (
      <div className="connect-wrap">
        <button
          className="btn btn--primary btn--sm"
          onClick={handleConnect}
          disabled={isPending}
          type="button"
        >
          <Wallet size={16} />
          {isPending ? "Connecting…" : "Connect wallet"}
        </button>
        {error ? <span className="connect-error">{error}</span> : null}
      </div>
    );
  }

  return (
    <div className="connect-wrap" ref={wrapper}>
      <button
        className="account-btn"
        onClick={() => setOpen((value) => !value)}
        type="button"
        aria-expanded={open}
      >
        <span className="account-btn__dot" />
        <span className="mono">{shortAddress(address)}</span>
        <ChevronDown size={14} />
      </button>
      {open ? (
        <div className="menu">
          <div className="menu__label">Connected wallet</div>
          <div className="menu__address mono">{address}</div>
          <button className="menu__item" onClick={copyAddress} type="button">
            {copied ? <Check size={15} /> : <Copy size={15} />}
            {copied ? "Copied" : "Copy address"}
          </button>
          <a
            className="menu__item"
            href={explorerAddressUrl(chainId ?? vaultConfig.chainId, address)}
            target="_blank"
            rel="noreferrer"
          >
            <ExternalLink size={15} />
            View on explorer
          </a>
          <button
            className="menu__item menu__item--danger"
            onClick={() => {
              disconnect();
              setOpen(false);
            }}
            type="button"
          >
            <LogOut size={15} />
            Disconnect
          </button>
        </div>
      ) : null}
    </div>
  );
}
