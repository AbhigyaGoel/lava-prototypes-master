import { db } from "@/lib/db";
import { evaluateChapters } from "@/lib/compliance";
import { countByStatus, filterChapters, flagStats, parseFilters, toQuery } from "@/lib/dashboard";
import { ExportMenu } from "@/components/export-menu";
import { ImportChaptersButton } from "@/components/import-chapters";
import { Summary, summarySentence } from "@/components/dashboard/summary";
import { ChapterTable } from "@/components/dashboard/chapter-table";
import { getSettings } from "@/lib/settings";

export default async function Dashboard({ searchParams }: PageProps<"/">) {
  const filters = parseFilters(await searchParams);
  const { region, district } = filters;

  const settings = await getSettings();
  const [scope, places] = await Promise.all([
    evaluateChapters({ region, district }, settings),
    db.chapter.findMany({ select: { region: true, district: true }, distinct: ["region", "district"], orderBy: [{ region: "asc" }, { district: "asc" }] }),
  ]);

  const counts = countByStatus(scope);
  const submitted = scope.filter((c) => c.evaluation.submitted).length;
  const rows = filterChapters(scope, filters);
  const scopeLabel = [region, district].filter(Boolean).join(", ") || "All chapters";

  return (
    <div className="space-y-8">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-sm text-zinc-500">{new Date().getFullYear()} annual review · {scopeLabel}</p>
          <h1 className="mt-1 text-2xl font-semibold tracking-tight text-zinc-900">{summarySentence(counts, scope.length)}</h1>
        </div>
        <div className="flex flex-wrap gap-2">
          <ImportChaptersButton />
          <ExportMenu query={toQuery(filters)} />
        </div>
      </header>

      <Summary counts={counts} total={scope.length} submitted={submitted} filters={filters} />

      <ChapterTable rows={rows} scopeTotal={scope.length} filters={filters} places={places} issues={flagStats(scope)} />
    </div>
  );
}
