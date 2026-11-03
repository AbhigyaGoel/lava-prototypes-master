"use client";
import { useEffect, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

const STATUSES = [
  { value: "", label: "All" },
  { value: "approved", label: "Approved" },
  { value: "declined", label: "Declined" },
];
const RANGES = [
  { value: "7", label: "Last 7 days" },
  { value: "30", label: "Last 30 days" },
  { value: "90", label: "Last 90 days" },
  { value: "all", label: "All time" },
];

export function PurchaseFilters({ officers }: { officers: string[] }) {
  const router = useRouter();
  const path = usePathname();
  const sp = useSearchParams();
  const [q, setQ] = useState(sp.get("q") ?? "");

  function set(key: string, value: string) {
    const next = new URLSearchParams(sp.toString());
    if (value) next.set(key, value); else next.delete(key);
    router.replace(`${path}${next.size ? `?${next}` : ""}`, { scroll: false });
  }

  // Search as you type, lightly debounced.
  useEffect(() => {
    if ((sp.get("q") ?? "") === q) return;
    const t = setTimeout(() => set("q", q.trim()), 250);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q]);

  const status = sp.get("status") ?? "";
  return (
    <div className="filters">
      <input className="search" type="search" placeholder="Search store, officer or card" aria-label="Search store, officer or card"
        value={q} onChange={(e) => setQ(e.target.value)} />
      <div className="filters" role="group" aria-label="Status" style={{ gap: 10 }}>
        {STATUSES.map((s) => (
          <button key={s.label} type="button" className="chip" aria-pressed={status === s.value} onClick={() => set("status", s.value)}>
            {s.label}
          </button>
        ))}
      </div>
      <select aria-label="Officer" value={sp.get("officer") ?? ""} onChange={(e) => set("officer", e.target.value)}>
        <option value="">Officer: Anyone</option>
        {officers.map((o) => <option key={o} value={o}>Officer: {o}</option>)}
      </select>
      <select aria-label="Date range" value={sp.get("days") ?? "30"} onChange={(e) => set("days", e.target.value === "30" ? "" : e.target.value)}>
        {RANGES.map((r) => <option key={r.value} value={r.value}>{r.label}</option>)}
      </select>
    </div>
  );
}
