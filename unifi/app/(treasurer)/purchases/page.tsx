import Link from "next/link";
import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { listPurchases, officerNames, parseFilters } from "@/lib/purchases";
import { fmt } from "@/lib/money";
import { reasonText, whenShort } from "@/lib/display";
import { PurchaseFilters } from "@/components/PurchaseFilters";
import { PurchaseStatus } from "@/components/Pills";

export const dynamic = "force-dynamic";

type SP = Record<string, string | string[] | undefined>;

export default async function Purchases({ searchParams }: { searchParams: Promise<SP> }) {
  const sp = await searchParams;
  const db = await getDb();
  const filters = parseFilters(sp);
  const [rows, officers, [{ n: total }]] = await Promise.all([
    listPurchases(db, CLUB_ID, filters),
    officerNames(db, CLUB_ID),
    db.query<{ n: number }>(`SELECT COUNT(*)::int AS n FROM authorizations WHERE club_id = $1`, [CLUB_ID]),
  ]);
  const qs = new URLSearchParams(Object.entries(sp).flatMap(([k, v]) => (typeof v === "string" ? [[k, v]] : []))).toString();

  return (
    <>
      <div className="page-head">
        <h1>Purchases</h1>
        <a className="btn secondary" href={`/api/purchases/export${qs ? `?${qs}` : ""}`} download>Export CSV</a>
      </div>

      <PurchaseFilters officers={officers} />

      <section className="panel" aria-label="Purchases">
        {rows.length === 0 ? (
          <p className="panel-empty">
            {total === 0 ? "No purchases yet. They show up here within seconds." : "No purchases match these filters."}
          </p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr><th>When</th><th>Store</th><th>Card</th><th>Officer</th><th className="r">Amount</th><th>Status</th><th>Reason</th></tr>
              </thead>
              <tbody>
                {rows.map((p) => (
                  <tr key={p.id}>
                    <td>{whenShort(p.created_at)}</td>
                    <td className="strong">{p.merchant}</td>
                    <td>{p.card_id ? <Link href={`/cards/${p.card_id}`}>{p.purpose}</Link> : "Unknown card"}</td>
                    <td>{p.officer ?? "—"}</td>
                    <td className="r">{fmt(p.amount_cents)}</td>
                    <td><PurchaseStatus decision={p.decision} /></td>
                    <td className="wrap">{reasonText(p.decline_reason, p.limit_cents)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </>
  );
}
