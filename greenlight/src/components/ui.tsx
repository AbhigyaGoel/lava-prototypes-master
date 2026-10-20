import type { ReactNode } from "react";
import type { Status } from "@/lib/compliance";

// Hue is reserved for status (see globals.css). Each status also has its own
// shape so it never depends on color alone.
type StatusStyle = {
  label: string; // exported value and compact badge text
  headline: string; // human label used on the dashboard
  description: string;
  icon: string; // icon color
  text: string; // readable text color on white
  fill: string; // bar segment fill
};

export const STATUS_META: Record<Status, StatusStyle> = {
  red: {
    label: "Red", headline: "At risk", description: "Revoked, not found, or no recent IRS filing",
    icon: "text-red-600", text: "text-red-700", fill: "bg-red-600",
  },
  yellow: {
    label: "Yellow", headline: "Needs review", description: "Name, fiscal year, or document issue",
    icon: "text-amber-500", text: "text-amber-700", fill: "bg-amber-400",
  },
  green: {
    label: "Green", headline: "Cleared", description: "Submitted, nothing flagged",
    icon: "text-emerald-600", text: "text-emerald-700", fill: "bg-emerald-600",
  },
  grey: {
    label: "Not submitted", headline: "Awaiting documents", description: "Documents not yet submitted",
    icon: "text-zinc-400", text: "text-zinc-600", fill: "bg-zinc-200",
  },
};

export const STATUS_DESCRIPTION: Record<Status, string> = {
  red: STATUS_META.red.description,
  yellow: STATUS_META.yellow.description,
  green: STATUS_META.green.description,
  grey: STATUS_META.grey.description,
};

export function StatusIcon({ status, className = "size-4" }: { status: Status; className?: string }) {
  const color = STATUS_META[status].icon;
  const common = { viewBox: "0 0 16 16", className: `${className} shrink-0 ${color}`, "aria-hidden": true } as const;
  switch (status) {
    case "red":
      return (
        <svg {...common} fill="currentColor">
          <path fillRule="evenodd" d="M8 15A7 7 0 108 1a7 7 0 000 14zm0-10.25a.75.75 0 01.75.75v3a.75.75 0 01-1.5 0v-3A.75.75 0 018 4.75zM8 11.5a.875.875 0 100-1.75.875.875 0 000 1.75z" clipRule="evenodd" />
        </svg>
      );
    case "yellow":
      return (
        <svg {...common} fill="currentColor">
          <path fillRule="evenodd" d="M6.701 2.25c.577-1 2.02-1 2.598 0l5.196 9a1.5 1.5 0 01-1.299 2.25H2.804a1.5 1.5 0 01-1.3-2.25l5.197-9zM8 5.25a.75.75 0 01.75.75v2.5a.75.75 0 01-1.5 0V6A.75.75 0 018 5.25zm0 6.5a.85.85 0 100-1.7.85.85 0 000 1.7z" clipRule="evenodd" />
        </svg>
      );
    case "green":
      return (
        <svg {...common} fill="currentColor">
          <path fillRule="evenodd" d="M8 15A7 7 0 108 1a7 7 0 000 14zm3.844-8.791a.75.75 0 00-1.188-.918l-3.7 4.79-1.649-1.833a.75.75 0 10-1.114 1.004l2.25 2.5a.75.75 0 001.15-.043l4.25-5.5z" clipRule="evenodd" />
        </svg>
      );
    case "grey":
      return (
        <svg {...common} fill="none" stroke="currentColor" strokeWidth="1.5" strokeDasharray="2.2 1.8">
          <circle cx="8" cy="8" r="6.25" />
        </svg>
      );
  }
}

export function StatusBadge({ status }: { status: Status }) {
  const m = STATUS_META[status];
  return (
    <span className={`inline-flex items-center gap-1.5 whitespace-nowrap rounded-md bg-white px-2 py-0.5 text-xs font-medium ring-1 ring-inset ring-zinc-200 ${m.text}`}>
      <StatusIcon status={status} className="size-3.5" />
      {m.headline}
    </span>
  );
}

const GREEK: Record<string, string> = {
  alpha: "α", beta: "β", gamma: "γ", delta: "δ", epsilon: "ε", zeta: "ζ", eta: "η", theta: "θ",
  iota: "ι", kappa: "κ", lambda: "λ", mu: "μ", nu: "ν", xi: "ξ", omicron: "ο", pi: "π",
  rho: "ρ", sigma: "σ", tau: "τ", upsilon: "υ", phi: "φ", chi: "χ", psi: "ψ", omega: "ω",
};

/** "Alpha Beta" → "αβ"; names that aren't Greek letters fall back to initials. */
export function monogram(name: string, upper = false): string {
  const words = name.trim().split(/\s+/).filter(Boolean);
  const greek = words.map((w) => GREEK[w.toLowerCase()]);
  if (words.length && greek.every(Boolean)) {
    const s = greek.join("").slice(0, 3);
    return upper ? s.toUpperCase() : s;
  }
  return words.slice(0, 2).map((w) => w[0]!.toUpperCase()).join("") || "?";
}

export function ChapterAvatar({ name }: { name: string }) {
  return (
    <span aria-hidden className="inline-flex size-8 shrink-0 items-center justify-center rounded-md bg-zinc-100 font-serif text-[15px] leading-none text-zinc-700">
      {monogram(name)}
    </span>
  );
}

export function Card({ title, action, children, className = "" }: { title?: ReactNode; action?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <section className={`rounded-lg border border-zinc-200 bg-white ${className}`}>
      {title && (
        <header className="flex items-center justify-between gap-4 border-b border-zinc-100 px-5 py-3">
          <h2 className="text-sm font-semibold text-zinc-900">{title}</h2>
          {action}
        </header>
      )}
      <div className="p-5">{children}</div>
    </section>
  );
}

export function Logo({ className = "" }: { className?: string }) {
  return (
    <span className={`inline-flex items-center gap-2 font-semibold tracking-tight text-zinc-900 ${className}`}>
      <svg viewBox="0 0 24 24" className="size-6" aria-hidden>
        <rect width="24" height="24" rx="6" className="fill-emerald-600" />
        <path d="M7 12.5l3.2 3.2L17 9" fill="none" stroke="white" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      Greenlight
    </span>
  );
}

export const buttonClass = {
  primary:
    "inline-flex items-center justify-center gap-2 rounded-md bg-zinc-900 px-3 py-1.5 text-sm font-medium text-white hover:bg-zinc-700 disabled:cursor-not-allowed disabled:opacity-50",
  secondary:
    "inline-flex items-center justify-center gap-2 rounded-md bg-white px-3 py-1.5 text-sm font-medium text-zinc-800 ring-1 ring-inset ring-zinc-300 hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50",
  ghost: "inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-sm font-medium text-zinc-600 hover:bg-zinc-100",
};

export function DefinitionList({ items }: { items: [ReactNode, ReactNode][] }) {
  return (
    <dl className="grid grid-cols-1 gap-x-6 gap-y-3 text-sm sm:grid-cols-[max-content_1fr]">
      {items.map(([k, v], i) => (
        <div key={i} className="contents">
          <dt className="text-zinc-500">{k}</dt>
          <dd className="font-medium text-zinc-900">{v}</dd>
        </div>
      ))}
    </dl>
  );
}
