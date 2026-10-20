"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";

type FilterKey = "region" | "district" | "flag";

export function FilterBar({
  places,
  issues,
  region,
  district,
  flag,
}: {
  places: { region: string; district: string }[];
  issues: { code: string; label: string; count: number }[];
  region?: string;
  district?: string;
  flag?: string;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const regions = [...new Set(places.map((p) => p.region))];
  const districts = [...new Set(places.filter((p) => !region || p.region === region).map((p) => p.district))].sort(
    (a, b) => a.localeCompare(b, undefined, { numeric: true }),
  );

  const set = (key: FilterKey, value: string) => {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    // A district only makes sense inside its region
    if (key === "region" && (!value || !places.some((p) => p.region === value && p.district === district))) next.delete("district");
    const qs = next.toString();
    router.push(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
  };

  const select = (on: boolean) =>
    `rounded-md border-0 py-1.5 pl-2.5 pr-8 text-sm ring-1 ring-inset focus:ring-2 focus:ring-zinc-900 ${
      on ? "bg-zinc-50 font-medium text-zinc-900 ring-zinc-400" : "bg-white text-zinc-600 ring-zinc-200 hover:ring-zinc-300"
    }`;
  return (
    <div className="flex flex-wrap items-center gap-2">
      <select aria-label="Issue" className={select(!!flag)} value={flag ?? ""} onChange={(e) => set("flag", e.target.value)}>
        <option value="">Any issue</option>
        {issues.map((i) => <option key={i.code} value={i.code}>{`${i.label} (${i.count})`}</option>)}
      </select>
      <select aria-label="Region" className={select(!!region)} value={region ?? ""} onChange={(e) => set("region", e.target.value)}>
        <option value="">All regions</option>
        {regions.map((r) => <option key={r} value={r}>{r}</option>)}
      </select>
      <select aria-label="District" className={select(!!district)} value={district ?? ""} onChange={(e) => set("district", e.target.value)}>
        <option value="">All districts</option>
        {districts.map((d) => <option key={d} value={d}>{d}</option>)}
      </select>
    </div>
  );
}
