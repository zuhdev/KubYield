import {
  ArrowDownLeft,
  ArrowUpRight,
  ExternalLink,
  Inbox,
  Zap,
} from "lucide-react";
import { explorerTxUrl } from "../lib/chains";
import { formatAmount, shortAddress, timeAgo } from "../lib/format";
import { vaultConfig, type ActivityItem, type VaultSnapshot } from "../lib/vault";

export function ActivityTable({
  snapshot,
  eventsError,
}: {
  snapshot: VaultSnapshot;
  eventsError: boolean;
}) {
  return (
    <section className="card activity-card" id="activity">
      <div className="card__head">
        <div>
          <div className="eyebrow">On-chain</div>
          <h2 className="card__title card__title--sm">Recent activity</h2>
        </div>
        <span className="activity-count">
          {snapshot.activity.length > 0
            ? `${snapshot.activity.length} events`
            : "No events"}
        </span>
      </div>

      {snapshot.activity.length === 0 ? (
        <div className="empty">
          <Inbox size={22} />
          <div>
            <strong>Nothing indexed yet.</strong>
            <p>
              {eventsError
                ? "The RPC rejected the log query. Increase the lookup window or use a stronger RPC."
                : "Deposits, withdrawals, and harvests will appear here after the vault is used."}
            </p>
          </div>
        </div>
      ) : (
        <div className="table-wrap">
          <table className="activity-table">
            <thead>
              <tr>
                <th>Action</th>
                <th className="hide-sm">Wallet</th>
                <th className="align-right">Amount</th>
                <th className="hide-sm">Time</th>
                <th className="align-right">Tx</th>
              </tr>
            </thead>
            <tbody>
              {snapshot.activity.map((item) => (
                <tr key={item.id}>
                  <td>
                    <span className={`activity-type activity-type--${item.type}`}>
                      {item.type === "deposit" ? <ArrowDownLeft size={13} /> : null}
                      {item.type === "withdraw" ? <ArrowUpRight size={13} /> : null}
                      {item.type === "harvest" ? <Zap size={13} /> : null}
                      {capitalize(item.type)}
                    </span>
                  </td>
                  <td className="mono activity-wallet">
                    {shortAddress(item.address)}
                  </td>
                  <td className="align-right">
                    <AmountCell item={item} />
                  </td>
                  <td className="hide-sm activity-time">
                    {item.timestamp ? timeAgo(item.timestamp) : "—"}
                  </td>
                  <td className="align-right">
                    <a
                      className="tx-link"
                      href={explorerTxUrl(vaultConfig.chainId, item.txHash)}
                      target="_blank"
                      rel="noreferrer"
                      aria-label="View transaction"
                    >
                      <ExternalLink size={14} />
                    </a>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

function AmountCell({ item }: { item: ActivityItem }) {
  if (item.type === "harvest") {
    return (
      <span className="amount-cell">
        <strong className="text-lime">
          +{formatAmount(item.rewards ?? 0, 2)} LP
        </strong>
        <span>fee {formatAmount(item.fee ?? 0, 2)}</span>
      </span>
    );
  }

  return (
    <span className="amount-cell">
      <strong className={item.type === "deposit" ? "text-lime" : ""}>
        {item.type === "deposit" ? "+" : "−"}
        {formatAmount(item.assets ?? 0, 2)} LP
      </strong>
      <span>{formatAmount(item.shares ?? 0, 2)} shares</span>
    </span>
  );
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}
