import Link from "next/link";
import { db } from "@/lib/db";
import { fmtDate } from "@/lib/compliance";
import { Logo, monogram } from "@/components/ui";
import { NavLinks } from "@/components/nav-links";
import { getSettings } from "@/lib/settings";

export const dynamic = "force-dynamic";

export default async function HqLayout({ children }: LayoutProps<"/">) {
  const [settings, lastLoad] = await Promise.all([
    getSettings(),
    db.irsDataLoad.findFirst({ orderBy: { loadedAt: "desc" } }),
  ]);

  return (
    <div className="min-h-screen lg:flex">
      <aside className="sticky top-0 hidden h-screen w-56 shrink-0 flex-col border-r border-zinc-200 bg-zinc-50 px-3 py-4 lg:flex">
        <Link href="/" className="px-2 py-1"><Logo /></Link>

        <div className="mt-5 flex items-center gap-2.5 px-2">
          <span className="inline-flex size-7 items-center justify-center rounded-md bg-white font-serif text-xs text-zinc-700 ring-1 ring-inset ring-zinc-200">
            {monogram(settings.orgName, true)}
          </span>
          <div className="min-w-0 leading-tight">
            <div className="truncate text-sm font-medium text-zinc-900">{settings.orgName}</div>
            <div className="text-xs text-zinc-500">National HQ</div>
          </div>
        </div>

        <div className="mt-5"><NavLinks /></div>

        <p className="mt-auto px-2 text-xs leading-relaxed text-zinc-500">
          {lastLoad ? (
            <>IRS data as of {fmtDate(lastLoad.loadedAt)}<br />BMF, revocations, 990-N</>
          ) : (
            <>IRS data not loaded. Run <code className="font-mono">npm run irs:load</code>.</>
          )}
        </p>
      </aside>

      <header className="sticky top-0 z-20 flex h-14 items-center gap-6 border-b border-zinc-200 bg-white px-4 lg:hidden">
        <Link href="/"><Logo /></Link>
        <NavLinks orientation="horizontal" />
      </header>

      <main className="mx-auto w-full min-w-0 max-w-[1180px] px-4 py-8 sm:px-8 lg:py-12">{children}</main>
    </div>
  );
}
