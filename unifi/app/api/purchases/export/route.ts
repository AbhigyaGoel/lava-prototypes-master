import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { listPurchases, parseFilters } from "@/lib/purchases";
import { reasonText } from "@/lib/display";

function cell(v: string) {
  // Quote everything; neutralise spreadsheet formulas from merchant names.
  const safe = /^[=+\-@]/.test(v) ? `'${v}` : v;
  return `"${safe.replace(/"/g, '""')}"`;
}

// Frame 7 "Export CSV": the same rows and filters as the Purchases page.
export async function GET(req: Request) {
  const sp = Object.fromEntries(new URL(req.url).searchParams);
  const rows = await listPurchases(await getDb(), CLUB_ID, { ...parseFilters(sp), limit: 10000 });
  const lines = [
    ["When", "Store", "Card", "Officer", "Amount", "Status", "Reason"].map(cell).join(","),
    ...rows.map((r) => [
      new Date(r.created_at).toISOString(),
      r.merchant,
      r.purpose ?? "",
      r.officer ?? "",
      (r.amount_cents / 100).toFixed(2),
      r.decision === "APPROVED" ? "Approved" : "Declined",
      reasonText(r.decline_reason, r.limit_cents),
    ].map(cell).join(",")),
  ];
  return new Response(lines.join("\r\n") + "\r\n", {
    headers: {
      "content-type": "text/csv; charset=utf-8",
      "content-disposition": `attachment; filename="unifi-purchases-${new Date().toISOString().slice(0, 10)}.csv"`,
    },
  });
}
