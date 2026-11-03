import Link from "next/link";
import { redirect } from "next/navigation";
import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { getClub } from "@/lib/club";
import { clubSummary, type CardRow } from "@/lib/ledger";
import { listPurchases } from "@/lib/purchases";
import { fmt } from "@/lib/money";
import { ago, day } from "@/lib/format";
import { CARD_STATUS, dollarsShort, greeting, startOfMonthISO, whenShort } from "@/lib/display";
import { PurchaseStatus } from "@/components/Pills";

export const dynamic = "force-dynamic";

export default async function Home() {
  const db = await getDb();
  const s = await clubSummary(db, CLUB_ID);
  if (!s.bank) redirect("/setup");
  const club = await getClub();
  const openCards = await db.query<CardRow>(
    `SELECT * FROM cards WHERE club_id = $1 AND status = 'open' ORDER BY expires_at ASC LIMIT 5`, [CLUB_ID]);
  const latest = await listPurchases(db, CLUB_ID, { limit: 5 });
  const [month] = await db.query<{ c: number; n: number }>(
    `SELECT COALESCE(SUM(amount_cents), 0)::int AS c, COUNT(*)::int AS n FROM authorizations
     WHERE club_id = $1 AND status IN ('held', 'settled') AND created_at >= $2`, [CLUB_ID, startOfMonthISO()]);
  const [{ n: cardCount }] = await db.query<{ n: number }>(`SELECT COUNT(*)::int AS n FROM cards WHERE club_id = $1`, [CLUB_ID]);

  return (
    <>
      <div className="page-head">
        <div>
          <p className="eyebrow">{greeting()}</p>
          <h1>{club.name}</h1>
        </div>
        <Link className="btn" href="/cards/new">+ New card</Link>
      </div>

      {s.bank.status === "broken" && (
        <p className="notice error">
          The bank connection needs fixing. New cards and purchases are paused. <Link href="/setup">Reconnect</Link>
        </p>
      )}

      <div className="stats">
        <div className="stat lead">
          <span className="k">Club balance</span>
          <span className="v">{fmt(s.bank.available_cents)}</span>
          <span className="s">{s.bank.institution_name} ••{s.bank.mask} · updated {ago(s.bank.balance_refreshed_at)}</span>
        </div>
        <div className="stat">
          <span className="k">Available for new cards</span>
          <span className="v">{fmt(s.availableForNewCardsCents)}</span>
          <span className="s">Balance minus open card limits</span>
        </div>
        <div className="stat">
          <span className="k">Open cards</span>
          <span className="v">{s.openCards}</span>
          <span className="s">{dollarsShort(s.openLimitsCents)} in limits</span>
        </div>
        <div className="stat">
          <span className="k">Spent this month</span>
          <span className="v">{fmt(month.c)}</span>
          <span className="s">{month.n} purchase{month.n === 1 ? "" : "s"}</span>
        </div>
      </div>

      {cardCount === 0 ? (
        <div className="panel">
          <div className="panel-empty">
            <h2>Make your first card</h2>
            <p>Give an officer a card for exactly what the next event needs.</p>
            <Link className="btn" href="/cards/new">+ New card</Link>
          </div>
        </div>
      ) : (
        <div className="two-up">
          <section className="panel" aria-labelledby="open-h">
            <div className="panel-head"><h2 id="open-h">Open cards</h2><Link href="/cards">See all</Link></div>
            {openCards.length === 0 ? (
              <p className="panel-empty">No open cards. Used and closed cards are under Cards.</p>
            ) : (
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Purpose</th><th>Officer</th><th>Expires</th><th className="r">Limit</th><th>Status</th></tr></thead>
                  <tbody>
                    {openCards.map((c) => (
                      <tr key={c.id}>
                        <td className="strong"><Link href={`/cards/${c.id}`}>{c.purpose}</Link></td>
                        <td>{c.recipient_name}</td>
                        <td>{day(c.expires_at)}</td>
                        <td className="r">{fmt(c.limit_cents)}</td>
                        <td><span className={`pill ${CARD_STATUS[c.status].tone}`}>{CARD_STATUS[c.status].label}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>

          <section className="panel" aria-labelledby="latest-h">
            <div className="panel-head"><h2 id="latest-h">Latest purchases</h2><Link href="/purchases">See all</Link></div>
            {latest.length === 0 ? (
              <p className="panel-empty">No purchases yet. They show up here within seconds.</p>
            ) : (
              <div className="table-wrap">
                <table>
                  <thead><tr><th>Store</th><th>Officer</th><th>When</th><th className="r">Amount</th><th>Status</th></tr></thead>
                  <tbody>
                    {latest.map((p) => (
                      <tr key={p.id}>
                        <td className="strong">{p.card_id ? <Link href={`/cards/${p.card_id}`}>{p.merchant}</Link> : p.merchant}</td>
                        <td>{p.officer ?? "—"}</td>
                        <td>{whenShort(p.created_at)}</td>
                        <td className="r">{fmt(p.amount_cents)}</td>
                        <td><PurchaseStatus decision={p.decision} /></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>
      )}
    </>
  );
}
