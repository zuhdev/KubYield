import { BookOpen, GitBranch, Sparkles } from "lucide-react";
import { useAccount, useSwitchChain } from "wagmi";
import { chainForId } from "../lib/chains";
import { vaultConfig } from "../lib/vault";
import { ConnectButton } from "./ConnectButton";
import { Logo } from "./Logo";

const REPO_URL = "https://github.com/zuhdev/KubYield";

export function TopNav({ demo }: { demo: boolean }) {
  const { isConnected, chainId } = useAccount();
  const { switchChain, isPending } = useSwitchChain();
  const targetChain = chainForId(vaultConfig.chainId);
  const wrongNetwork = isConnected && chainId !== vaultConfig.chainId;

  return (
    <header className="nav">
      <div className="nav__inner">
        <div className="nav__left">
          <Logo />
          <span className="nav__divider" />
          <nav className="nav__links" aria-label="Primary">
            <a className="nav__link nav__link--active" href="#vault">
              Vault
            </a>
            <a className="nav__link" href="#activity">
              Activity
            </a>
            <a
              className="nav__link"
              href={`${REPO_URL}#readme`}
              target="_blank"
              rel="noreferrer"
            >
              Docs
            </a>
          </nav>
        </div>

        <div className="nav__right">
          {demo ? (
            <span className="pill pill--amber">
              <Sparkles size={12} />
              Preview
            </span>
          ) : null}
          {wrongNetwork ? (
            <button
              className="pill pill--warning"
              onClick={() => switchChain({ chainId: vaultConfig.chainId })}
              disabled={isPending}
              type="button"
            >
              <span className="dot dot--amber" />
              {isPending ? "Switching…" : "Switch network"}
            </button>
          ) : (
            <span className="pill pill--network">
              <span className="dot dot--green" />
              {targetChain.name}
            </span>
          )}
          <a
            className="icon-btn nav__github"
            href={REPO_URL}
            target="_blank"
            rel="noreferrer"
            aria-label="GitHub repository"
          >
            <GitBranch size={17} />
          </a>
          <a
            className="icon-btn nav__docs"
            href={`${REPO_URL}#readme`}
            target="_blank"
            rel="noreferrer"
            aria-label="Documentation"
          >
            <BookOpen size={17} />
          </a>
          <ConnectButton />
        </div>
      </div>
    </header>
  );
}
