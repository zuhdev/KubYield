import { useMemo, useState } from "react";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Info, Radio } from "lucide-react";
import { formatAmount, formatChartDate, formatCompact, formatUsd } from "../lib/format";
import type { HistoryPoint, VaultSnapshot } from "../lib/vault";

const RANGES = [
  { label: "7D", days: 7 },
  { label: "30D", days: 30 },
  { label: "90D", days: 90 },
];

type Metric = "tvl" | "sharePrice";

export function PerformanceChart({ snapshot }: { snapshot: VaultSnapshot }) {
  const [range, setRange] = useState(30);
  const [metric, setMetric] = useState<Metric>("tvl");

  const data = useMemo(() => {
    const cutoff = Date.now() - range * 86_400_000;
    const filtered = snapshot.history.filter((point) => point.timestamp >= cutoff);
    const points = filtered.length > 1 ? filtered : snapshot.history;
    return points.map((point) => ({
      ...point,
      label: formatChartDate(point.timestamp),
    }));
  }, [range, snapshot.history]);

  const first = data[0];
  const last = data[data.length - 1];
  const metricKey = metric === "tvl" ? "tvl" : "sharePrice";
  const change =
    first && last && first[metricKey] > 0
      ? ((last[metricKey] - first[metricKey]) / first[metricKey]) * 100
      : 0;

  const usdPerLp =
    snapshot.tvlUsd !== null && snapshot.tvl > 0
      ? snapshot.tvlUsd / snapshot.tvl
      : null;

  return (
    <section className="card chart-card">
      <div className="card__head chart-card__head">
        <div>
          <div className="eyebrow">
            <span className={`dot ${snapshot.mode === "live" ? "dot--green" : "dot--amber"}`} />
            {snapshot.mode === "live" ? "Live vault" : "Preview data"}
          </div>
          <h2 className="card__title">Vault performance</h2>
        </div>
        <div className="chart-controls">
          <div className="segmented">
            <button
              className={metric === "tvl" ? "segmented__btn is-active" : "segmented__btn"}
              onClick={() => setMetric("tvl")}
              type="button"
            >
              TVL
            </button>
            <button
              className={metric === "sharePrice" ? "segmented__btn is-active" : "segmented__btn"}
              onClick={() => setMetric("sharePrice")}
              type="button"
            >
              Share price
            </button>
          </div>
          <div className="segmented segmented--muted">
            {RANGES.map((item) => (
              <button
                key={item.label}
                className={range === item.days ? "segmented__btn is-active" : "segmented__btn"}
                onClick={() => setRange(item.days)}
                type="button"
              >
                {item.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="chart-summary">
        <div className="chart-summary__value">
          {metric === "tvl"
            ? snapshot.tvlUsd !== null
              ? formatUsd(snapshot.tvlUsd)
              : `${formatCompact(snapshot.tvl)} LP`
            : `${snapshot.sharePrice.toFixed(4)} LP`}
        </div>
        <span className={`trend ${change >= 0 ? "trend--up" : "trend--down"}`}>
          {change >= 0 ? "+" : ""}
          {change.toFixed(1)}%
          <span className="trend__period">/{range}D</span>
        </span>
      </div>

      <div className="chart-wrap">
        <ResponsiveContainer width="100%" height={286}>
          <AreaChart data={data} margin={{ top: 12, right: 24, left: 0, bottom: 0 }}>
            <defs>
              <linearGradient id="areaFill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#c8f36b" stopOpacity={0.28} />
                <stop offset="55%" stopColor="#c8f36b" stopOpacity={0.08} />
                <stop offset="100%" stopColor="#c8f36b" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid
              vertical={false}
              stroke="rgba(255,255,255,0.055)"
              strokeDasharray="3 6"
            />
            <XAxis
              dataKey="label"
              tickLine={false}
              axisLine={false}
              minTickGap={32}
              tick={{ fill: "#6f7a8c", fontSize: 11 }}
              dy={10}
            />
            <YAxis
              width={54}
              tickLine={false}
              axisLine={false}
              tick={{ fill: "#6f7a8c", fontSize: 11 }}
              tickFormatter={(value: number) =>
                metric === "tvl" ? formatCompact(value) : value.toFixed(3)
              }
              domain={["auto", "auto"]}
            />
            <Tooltip
              cursor={{ stroke: "rgba(200,243,107,0.25)" }}
              content={({ active, payload }) => {
                if (!active || !payload?.length) return null;
                const point = payload[0].payload as HistoryPoint;
                return (
                  <div className="chart-tooltip">
                    <div className="chart-tooltip__date">
                      {formatChartDate(point.timestamp)}
                    </div>
                    <div className="chart-tooltip__row">
                      <span>TVL</span>
                      <strong>
                        {usdPerLp !== null
                          ? formatUsd(point.tvl * usdPerLp)
                          : `${formatAmount(point.tvl, 2)} LP`}
                      </strong>
                    </div>
                    <div className="chart-tooltip__row">
                      <span>Share price</span>
                      <strong>{point.sharePrice.toFixed(4)} LP</strong>
                    </div>
                  </div>
                );
              }}
            />
            <Area
              type="monotone"
              dataKey={metricKey}
              stroke="#c8f36b"
              strokeWidth={2}
              fill="url(#areaFill)"
              dot={false}
              activeDot={{ r: 4, fill: "#c8f36b", stroke: "#0b1016", strokeWidth: 3 }}
              isAnimationActive={false}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      <div className="chart-foot">
        <span className="chart-foot__item">
          <Info size={13} />
          {metric === "tvl"
            ? "TVL includes idle and strategy assets."
            : "Share price is LP redeemable per vault share."}
        </span>
        <span className="chart-foot__item chart-foot__item--right">
          <Radio size={13} />
          {snapshot.mode === "live" ? "On-chain data" : "Demo dataset"}
        </span>
      </div>
    </section>
  );
}
