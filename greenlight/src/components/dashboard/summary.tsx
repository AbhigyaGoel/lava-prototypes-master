import Link from "next/link";
import { STATUS_ORDER, dashboardHref, type DashboardFilters, type StatusCounts } from "@/lib/dashboard";
import { STATUS_META, StatusIcon } from "@/components/ui";

function plural(n: number, one: string, many = `${one}s`) {
  return `${n} ${n === 1 ? one : many}`;
}

/** Plain-language status of the review, worst news first. */
export function summarySentence(counts: StatusCounts, total: number): string {
  if (total === 0) return "No chapters yet. Import a chapter list to start the review.";
  const action = counts.red + counts.yellow;
  const parts: string[] = [];
  if (action) parts.push(`${plural(action, "chapter")} ${action === 1 ? "needs" : "need"} HQ action`);
  if (counts.grey) parts.push(`${counts.grey} ${counts.grey === 1 ? "hasn't" : "haven't"} sent documents yet`);
  if (!parts.length) return `All ${plural(total, "chapter")} are cleared.`;
  return `${parts.join(", and ")}.`;
}

export function Summary({
  counts,
  total,
  submitted,
  filters,
}: {
  counts: StatusCounts;
  total: number;
  submitted: number;
  filters: DashboardFilters;
}) {
  const active = filters.status;
  return (
    <section aria-label="Review progress" className="space-y-3">
      <div className="flex h-2 gap-0.5 overflow-hidden rounded-full bg-zinc-100" role="img" aria-label={STATUS_ORDER.map((s) => `${STATUS_META[s].headline} ${counts[s]}`).join(", ")}>
        {STATUS_ORDER.filter((s) => counts[s] > 0).map((s) => (
          <span
            key={s}
            className={`h-full transition-opacity ${STATUS_META[s].fill} ${active && active !== s ? "opacity-25" : ""}`}
            style={{ flexGrow: counts[s] }}
          />
        ))}
      </div>

      <div className="-ml-2 flex flex-wrap items-center gap-x-1 gap-y-2">
        {STATUS_ORDER.map((s) => {
          const on = active === s;
          return (
            <Link
              key={s}
              href={dashboardHref(filters, { status: s })}
              scroll={false}
              aria-current={on ? "true" : undefined}
              title={STATUS_META[s].description}
              className={`flex items-center gap-2 rounded-md px-2 py-1 text-sm transition ${
                on ? "bg-zinc-900 text-white" : active ? "text-zinc-400 hover:text-zinc-900" : "text-zinc-700 hover:bg-zinc-100"
              }`}
            >
              <StatusIcon status={s} className={`size-3.5 ${on ? "text-white!" : ""}`} />
              <span className="font-semibold tabular-nums">{counts[s]}</span>
              <span>{STATUS_META[s].headline.toLowerCase()}</span>
            </Link>
          );
        })}
        <span className="ml-auto text-sm tabular-nums text-zinc-500">
          <span className="font-semibold text-zinc-900">{submitted}</span> of {total} submitted
        </span>
      </div>
    </section>
  );
}
