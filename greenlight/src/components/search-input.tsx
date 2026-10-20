"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState, useTransition } from "react";

const DEBOUNCE_MS = 250;

/** Search box that keeps `?q=` in the URL so the server filters and exports the same rows. */
export function SearchInput({ initial = "" }: { initial?: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const params = useSearchParams();
  const [value, setValue] = useState(initial);
  const [synced, setSynced] = useState(initial);
  const [pushed, setPushed] = useState(initial);
  const [pending, startTransition] = useTransition();
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);

  useEffect(() => () => clearTimeout(timer.current), []);

  // Follow URL changes made elsewhere (e.g. "Clear all"), but not our own
  // debounced updates, so typing is never overwritten or interrupted.
  if (initial !== synced) {
    setSynced(initial);
    if (initial !== pushed) {
      setValue(initial);
      setPushed(initial);
    }
  }

  const push = (q: string) => {
    const next = new URLSearchParams(params);
    setPushed(q.trim());
    if (q.trim()) next.set("q", q.trim());
    else next.delete("q");
    const qs = next.toString();
    startTransition(() => router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false }));
  };

  return (
    <label className="relative flex w-full items-center sm:w-64">
      <span className="sr-only">Search chapters</span>
      <svg viewBox="0 0 20 20" fill="currentColor" className="pointer-events-none absolute left-2.5 size-4 text-zinc-400" aria-hidden>
        <path fillRule="evenodd" d="M9 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11zM2 9a7 7 0 1112.452 4.391l3.328 3.329a.75.75 0 11-1.06 1.06l-3.329-3.328A7 7 0 012 9z" clipRule="evenodd" />
      </svg>
      <input
        type="search"
        value={value}
        maxLength={100}
        placeholder="Search name, EIN, or email"
        onChange={(e) => {
          const q = e.target.value;
          setValue(q);
          clearTimeout(timer.current);
          timer.current = setTimeout(() => push(q), DEBOUNCE_MS);
        }}
        className="w-full rounded-md border-0 bg-white py-1.5 pl-8 pr-8 text-sm text-zinc-900 ring-1 ring-inset ring-zinc-200 placeholder:text-zinc-400 hover:ring-zinc-300 focus:ring-2 focus:ring-zinc-900"
      />
      {pending && <span className="absolute right-2.5 size-3.5 animate-spin rounded-full border-2 border-zinc-300 border-t-zinc-900" aria-hidden />}
    </label>
  );
}
