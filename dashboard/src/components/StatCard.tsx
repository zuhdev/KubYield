import type { ReactNode } from "react";
import { ArrowDownRight, ArrowUpRight } from "lucide-react";

interface StatCardProps {
  label: string;
  value: string;
  sub: string;
  icon: ReactNode;
  trend?: number | null;
  accent?: boolean;
}

export function StatCard({
  label,
  value,
  sub,
  icon,
  trend,
  accent = false,
}: StatCardProps) {
  const hasTrend = typeof trend === "number" && Number.isFinite(trend);

  return (
    <div className={`stat ${accent ? "stat--accent" : ""}`}>
      <div className="stat__top">
        <span className="stat__label">{label}</span>
        <span className="stat__icon">{icon}</span>
      </div>
      <div className="stat__value">{value}</div>
      <div className="stat__bottom">
        {hasTrend ? (
          <span className={`trend ${trend >= 0 ? "trend--up" : "trend--down"}`}>
            {trend >= 0 ? <ArrowUpRight size={12} /> : <ArrowDownRight size={12} />}
            {Math.abs(trend).toFixed(1)}%
          </span>
        ) : null}
        <span className="stat__sub">{sub}</span>
      </div>
    </div>
  );
}
