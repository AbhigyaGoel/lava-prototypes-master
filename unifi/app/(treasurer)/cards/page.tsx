import Link from "next/link";
import { redirect } from "next/navigation";
import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { clubSummary, type CardRow } from "@/lib/ledger";
import { fmt } from "@/lib/money";
import { day } from "@/lib/format";
import { CARD_STATUS } from "@/lib/display";

export const dynamic = "force-dynamic";

export default async function Cards() {
  const db = await getDb();
  const s = await clubSummary(db, CLUB_ID);
  if (!s.bank) redirect("/setup");
  const cards = await db.query<CardRow & { spent: number }>(
    `SELECT c.*, COALESCE(SUM(a.amount_cents) FILTER (WHERE a.status IN ('held','settled')), 0)::int AS spent
     FROM cards c LEFT JOIN authorizations a ON a.card_id = c.id
     WHERE c.club_id = $1 GROUP BY c.id ORDER BY c.created_at DESC LIMIT 200`, [CLUB_ID]);

  return (
    <>
      <div className="page-head">
        <h1>Cards</h1>
        <Link className="btn" href="/cards/new">+ New card</Link>
      </div>

      <section className="panel" aria-label="All cards">
        {cards.length === 0 ? (
          <div className="panel-empty">
            <h2>Make your first card</h2>
            <p>Give an officer a card for exactly what the next event needs.</p>
            <Link className="btn" href="/cards/new">+ New card</Link>
          </div>
        ) : (
          <div className="table-wrap">
            <table>
              <thead><tr><th>Purpose</th><th>Officer</th><th>Card</th><th>Expires</th><th className="r">Limit</th><th className="r">Spent</th><th>Status</th></tr></thead>
              <tbody>
                {cards.map((c) => (
                  <tr key={c.id}>
                    <td className="strong"><Link href={`/cards/${c.id}`}>{c.purpose}</Link></td>
                    <td>{c.recipient_name}</td>
                    <td>••{c.last4}</td>
                    <td>{day(c.expires_at)}</td>
                    <td className="r">{fmt(c.limit_cents)}</td>
                    <td className="r">{c.spent ? fmt(c.spent) : "—"}</td>
                    <td><span className={`pill ${CARD_STATUS[c.status].tone}`}>{CARD_STATUS[c.status].label}</span></td>
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
