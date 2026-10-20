// Dashboard view model: the filters the HQ dashboard understands and the
// aggregates it charts. Pure functions over evaluated chapters, shared by the
// dashboard page and the export route so "export current view" always matches.
import type { EvaluatedChapter, FlagCode, Status } from "@/lib/compliance";
import { formatEin } from "@/lib/irs/parse";

export const STATUS_ORDER: Status[] = ["red", "yellow", "green", "grey"];

export const FLAG_LABELS: Record<FlagCode, string> = {
  REVOKED: "Exempt status revoked",
  NO_RECENT_FILING: "No recent IRS filing",
  NOT_IN_IRS: "EIN not in IRS data",
  NAME_FORMAT: "Legal name off-format",
  FISCAL_YEAR: "Non-calendar fiscal year",
  EIN_MISMATCH: "Document EIN mismatch",
  UNREADABLE_DOCUMENT: "Unreadable document",
};

const FLAG_CODES = Object.keys(FLAG_LABELS) as FlagCode[];

export type DashboardFilters = {
  region?: string;
  district?: string;
  status?: Status;
  flag?: FlagCode;
  q?: string;
};

type RawParams = Record<string, string | string[] | undefined>;

function first(v: string | string[] | undefined) {
  const s = Array.isArray(v) ? v[0] : v;
  return s?.trim() || undefined;
}

/** Parse and validate dashboard search params; unknown values are dropped. */
export function parseFilters(sp: RawParams | URLSearchParams): DashboardFilters {
  const get = (k: string) => (sp instanceof URLSearchParams ? sp.get(k) ?? undefined : first(sp[k]))?.trim() || undefined;
  const status = get("status");
  const flag = get("flag");
  return {
    region: get("region"),
    district: get("district"),
    status: STATUS_ORDER.includes(status as Status) ? (status as Status) : undefined,
    flag: FLAG_CODES.includes(flag as FlagCode) ? (flag as FlagCode) : undefined,
    q: get("q")?.slice(0, 100),
  };
}

export function toQuery(f: DashboardFilters) {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(f)) if (v) p.set(k, v);
  return p.toString();
}

/** Link to the dashboard with `patch` applied; a value equal to the current one toggles it off. */
export function dashboardHref(current: DashboardFilters, patch: Partial<DashboardFilters>) {
  const next: DashboardFilters = { ...current };
  for (const [k, v] of Object.entries(patch) as [keyof DashboardFilters, string | undefined][]) {
    (next as Record<string, string | undefined>)[k] = v && current[k] === v ? undefined : v;
  }
  // A district belongs to a region; switching region drops it.
  if ("region" in patch && patch.region !== current.region) next.district = undefined;
  const qs = toQuery(next);
  return qs ? `/?${qs}` : "/";
}

function matchesQuery(c: EvaluatedChapter, q: string) {
  const needle = q.toLowerCase();
  const digits = q.replace(/\D/g, "");
  return (
    c.name.toLowerCase().includes(needle) ||
    (c.evaluation.irs.legalName ?? "").toLowerCase().includes(needle) ||
    c.treasurerEmail.toLowerCase().includes(needle) ||
    (digits.length >= 3 && (c.ein.includes(digits) || formatEin(c.ein).includes(q)))
  );
}

/** Apply the in-memory filters (status, flag, search). Region/district are applied in the DB query. */
export function filterChapters(chapters: EvaluatedChapter[], f: DashboardFilters) {
  return chapters
    .filter((c) => !f.status || c.evaluation.status === f.status)
    .filter((c) => !f.flag || c.evaluation.flags.some((fl) => fl.code === f.flag))
    .filter((c) => !f.q || matchesQuery(c, f.q))
    .sort(
      (a, b) =>
        STATUS_ORDER.indexOf(a.evaluation.status) - STATUS_ORDER.indexOf(b.evaluation.status) ||
        a.name.localeCompare(b.name),
    );
}

export type StatusCounts = Record<Status, number>;

export function countByStatus(chapters: EvaluatedChapter[]): StatusCounts {
  const counts: StatusCounts = { red: 0, yellow: 0, green: 0, grey: 0 };
  for (const c of chapters) counts[c.evaluation.status] += 1;
  return counts;
}

export type FlagStat = { code: FlagCode; label: string; severity: "red" | "yellow"; count: number };

/** How many chapters carry each flag, most common first (red before yellow on ties). */
export function flagStats(chapters: EvaluatedChapter[]): FlagStat[] {
  const stats = new Map<FlagCode, FlagStat>();
  for (const c of chapters) {
    for (const code of new Set(c.evaluation.flags.map((f) => f.code))) {
      const flag = c.evaluation.flags.find((f) => f.code === code)!;
      const prev = stats.get(code);
      stats.set(code, { code, label: FLAG_LABELS[code], severity: flag.severity, count: (prev?.count ?? 0) + 1 });
    }
  }
  return [...stats.values()].sort(
    (a, b) => b.count - a.count || (a.severity === b.severity ? 0 : a.severity === "red" ? -1 : 1),
  );
}

export type Issue = { tone: "red" | "yellow" | "green" | "grey"; title: string; detail?: string; more: number };

const DOC_NAMES = { determination: "determination letter", financial: "bank statement" } as const;

/** The one thing to say about a chapter in its dashboard row, worst problem first. */
export function primaryIssue(c: EvaluatedChapter): Issue {
  const ev = c.evaluation;
  const flags = [...ev.flags].sort((a, b) => (a.severity === b.severity ? 0 : a.severity === "red" ? -1 : 1));
  const missing = (Object.keys(DOC_NAMES) as (keyof typeof DOC_NAMES)[]).filter((k) => !ev.docs[k]).map((k) => DOC_NAMES[k]);
  if (flags.length) {
    const [top] = flags;
    return { tone: top!.severity, title: top!.title, detail: top!.detail, more: flags.length - 1 };
  }
  if (missing.length) return { tone: "grey", title: missing.length > 1 ? "Waiting on both documents" : `Waiting on ${missing[0]}`, more: 0 };
  return { tone: "green", title: "No issues found", more: 0 };
}

export type NextStep = { label: string; compose: "education" | "reminder" } | null;

/** What HQ should do next. Missing documents come first; flags get an education notice. */
export function nextStep(c: EvaluatedChapter): NextStep {
  const ev = c.evaluation;
  if (ev.status === "red") return { label: "Send notice", compose: "education" };
  if (!ev.submitted) return { label: "Send reminder", compose: "reminder" };
  if (ev.flags.length) return { label: "Send notice", compose: "education" };
  return null;
}
