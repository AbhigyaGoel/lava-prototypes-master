import Link from "next/link";
import type { ReactNode } from "react";
import type { DocWithFields, EvaluatedChapter, Status } from "@/lib/compliance";
import {
  FLAG_LABELS,
  STATUS_ORDER,
  dashboardHref,
  nextStep,
  primaryIssue,
  type DashboardFilters,
  type FlagStat,
} from "@/lib/dashboard";
import { formatEin } from "@/lib/irs/parse";
import { ChapterAvatar, STATUS_META, StatusIcon } from "@/components/ui";
import { ChapterRow } from "@/components/chapter-row";
import { FilterBar } from "@/components/filter-bar";
import { SearchInput } from "@/components/search-input";

const COLUMNS = ["Chapter", "Issue", "Documents", "Latest IRS filing", "Next step"];

function monthYear(d: Date) {
  return d.toLocaleDateString("en-US", { month: "short", year: "numeric", timeZone: "UTC" });
}

function DocLine({ doc, label }: { doc: DocWithFields | null; label: string }) {
  const state = !doc
    ? { mark: "–", tone: "text-zinc-400", note: "" }
    : doc.extractionStatus === "failed"
      ? { mark: "!", tone: "text-amber-700", note: " · unreadable" }
      : doc.extractionStatus === "pending" || doc.extractionStatus === "processing"
        ? { mark: "…", tone: "text-zinc-500", note: " · reading" }
        : { mark: "✓", tone: "text-zinc-700", note: "" };
  return (
    <div className={`flex items-center gap-1.5 whitespace-nowrap text-[13px] ${state.tone}`}>
      <span aria-hidden className="w-3 text-center font-medium">{state.mark}</span>
      <span>{label}{state.note}</span>
      <span className="sr-only">{doc ? "received" : "missing"}</span>
    </div>
  );
}

function ActiveChip({ href, children }: { href: string; children: ReactNode }) {
  return (
    <Link href={href} scroll={false} className="inline-flex items-center gap-1 rounded-md bg-zinc-100 py-0.5 pl-2 pr-1 text-xs font-medium text-zinc-800 hover:bg-zinc-200">
      {children}
      <svg viewBox="0 0 16 16" fill="currentColor" className="size-3.5 text-zinc-500" aria-hidden>
        <path d="M5.28 4.22a.75.75 0 00-1.06 1.06L6.94 8l-2.72 2.72a.75.75 0 101.06 1.06L8 9.06l2.72 2.72a.75.75 0 101.06-1.06L9.06 8l2.72-2.72a.75.75 0 00-1.06-1.06L8 6.94 5.28 4.22z" />
      </svg>
      <span className="sr-only">Remove filter</span>
    </Link>
  );
}

export function ChapterTable({
  rows,
  scopeTotal,
  filters,
  places,
  issues,
}: {
  rows: EvaluatedChapter[];
  scopeTotal: number;
  filters: DashboardFilters;
  places: { region: string; district: string }[];
  issues: FlagStat[];
}) {
  const groups = STATUS_ORDER.map((s) => ({ status: s, rows: rows.filter((r) => r.evaluation.status === s) })).filter((g) => g.rows.length);
  const chips = [
    filters.status && { key: "status", label: STATUS_META[filters.status].headline, href: dashboardHref(filters, { status: undefined }) },
    filters.flag && { key: "flag", label: FLAG_LABELS[filters.flag], href: dashboardHref(filters, { flag: undefined }) },
    filters.region && { key: "region", label: filters.region, href: dashboardHref(filters, { region: undefined }) },
    filters.district && { key: "district", label: filters.district, href: dashboardHref(filters, { district: undefined }) },
    filters.q && { key: "q", label: `“${filters.q}”`, href: dashboardHref(filters, { q: undefined }) },
  ].filter((c): c is { key: string; label: string; href: string } => !!c);

  return (
    <section aria-label="Chapters">
      <div className="flex flex-wrap items-center gap-2 pb-3">
        <SearchInput initial={filters.q} />
        <FilterBar places={places} issues={issues} region={filters.region} district={filters.district} flag={filters.flag} />
        <span className="ml-auto text-sm tabular-nums text-zinc-500">
          {rows.length === scopeTotal ? `${scopeTotal} chapters` : `${rows.length} of ${scopeTotal} chapters`}
        </span>
      </div>

      {chips.length > 0 && (
        <div className="flex flex-wrap items-center gap-1.5 pb-3">
          {chips.map((c) => <ActiveChip key={c.key} href={c.href}>{c.label}</ActiveChip>)}
          <Link href="/" scroll={false} className="ml-1 text-xs font-medium text-zinc-500 underline decoration-zinc-300 underline-offset-2 hover:text-zinc-900">
            Clear all
          </Link>
        </div>
      )}

      <div className="overflow-x-auto rounded-lg border border-zinc-200">
        <table className="w-full min-w-[880px] text-left text-sm">
          <thead className="bg-zinc-50 text-xs text-zinc-500">
            <tr className="border-b border-zinc-200">
              {COLUMNS.map((c, i) => (
                <th key={c} scope="col" className={`py-2 font-medium ${i === 0 ? "pl-4 pr-3" : "px-3"}`}>{c}</th>
              ))}
            </tr>
          </thead>
          {groups.map((g) => (
            <tbody key={g.status} className="divide-y divide-zinc-100 border-b border-zinc-200 last:border-b-0">
              <GroupHeader status={g.status} count={g.rows.length} />
              {g.rows.map((c) => <Row key={c.id} chapter={c} />)}
            </tbody>
          ))}
          {groups.length === 0 && (
            <tbody>
              <tr>
                <td colSpan={COLUMNS.length} className="px-4 py-16 text-center">
                  <p className="text-sm font-medium text-zinc-800">No chapters match</p>
                  <p className="mt-1 text-sm text-zinc-500">
                    {scopeTotal === 0 ? "Import a chapter list to get started." : "Remove a filter or try a different search."}
                  </p>
                </td>
              </tr>
            </tbody>
          )}
        </table>
      </div>
    </section>
  );
}

function GroupHeader({ status, count }: { status: Status; count: number }) {
  const m = STATUS_META[status];
  return (
    <tr className="bg-white">
      <th colSpan={COLUMNS.length} scope="rowgroup" className="px-4 pb-2 pt-5 text-left font-normal">
        <span className="flex items-center gap-2">
          <StatusIcon status={status} className="size-4" />
          <span className="text-sm font-semibold text-zinc-900">{m.headline}</span>
          <span className="text-sm tabular-nums text-zinc-400">{count}</span>
          <span className="hidden text-xs text-zinc-500 sm:inline">· {m.description}</span>
        </span>
      </th>
    </tr>
  );
}

function Row({ chapter: c }: { chapter: EvaluatedChapter }) {
  const ev = c.evaluation;
  const href = `/chapters/${c.id}`;
  const issue = primaryIssue(c);
  const step = nextStep(c);
  const filing = ev.irs.latestFiling;
  return (
    <ChapterRow href={href}>
      <td className="py-3 pl-4 pr-3">
        <div className="flex items-center gap-3">
          <ChapterAvatar name={c.name} />
          <div className="min-w-0">
            <Link href={href} className="whitespace-nowrap font-medium text-zinc-900 hover:underline">{c.name}</Link>
            <div className="whitespace-nowrap text-xs text-zinc-500">
              {c.region} · {c.district} · <span className="font-mono text-[11px]">{formatEin(c.ein)}</span>
            </div>
          </div>
        </div>
      </td>
      <td className="max-w-[22rem] px-3 py-3">
        <div className="flex items-start gap-2">
          <StatusIcon status={issue.tone} className="mt-0.5 size-3.5" />
          <div className="min-w-0">
            <div className={issue.tone === "green" ? "text-zinc-500" : "text-zinc-900"}>
              {issue.title}
              {issue.more > 0 && <span className="ml-1.5 text-xs text-zinc-500">+{issue.more} more</span>}
            </div>
            {issue.detail && <div className="truncate text-xs text-zinc-500" title={issue.detail}>{issue.detail}</div>}
          </div>
        </div>
      </td>
      <td className="px-3 py-3">
        <DocLine doc={ev.docs.determination} label="IRS letter" />
        <DocLine doc={ev.docs.financial} label="Bank statement" />
      </td>
      <td className="whitespace-nowrap px-3 py-3">
        {filing ? (
          <>
            <div className="text-zinc-800">{filing.source === "990-N" ? "990-N" : "990 / 990-EZ"}</div>
            <div className="text-xs tabular-nums text-zinc-500">Period ending {monthYear(filing.periodEnd)}</div>
          </>
        ) : (
          <span className="text-zinc-400">None on file</span>
        )}
      </td>
      <td className="whitespace-nowrap py-3 pl-3 pr-4">
        {step ? (
          <Link
            href={`${href}?compose=${step.compose}`}
            className="inline-flex items-center gap-1 font-medium text-zinc-900 underline decoration-zinc-300 underline-offset-4 hover:decoration-zinc-900"
          >
            {step.label}
            <span aria-hidden>→</span>
          </Link>
        ) : (
          <span className="text-zinc-400">Nothing to do</span>
        )}
      </td>
    </ChapterRow>
  );
}
