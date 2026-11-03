import Link from "next/link";
import { notFound } from "next/navigation";
import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { getClub } from "@/lib/club";
import { getCard } from "@/lib/cards";
import { listPurchases } from "@/lib/purchases";
import { fmt } from "@/lib/money";
import { day, when } from "@/lib/format";
import { CARD_STATUS, reasonText, whenShort } from "@/lib/display";
import { CardActions } from "@/components/CardActions";
import { PurchaseStatus } from "@/components/Pills";

export const dynamic = "force-dynamic";

type Ev = { type: string; data: any; created_at: Date };

export default async function CardDetail({ params }: { params: Promise<{ id: string }> }) {
  const db = await getDb();
  const card = await getCard(db, CLUB_ID, (await params).id);
  if (!card) notFound();
  const club = await getClub();

  const purchases = await listPurchases(db, CLUB_ID, { cardId: card.id });
  const events = (await db.query<Ev>(
    `SELECT type, data, created_at FROM events WHERE card_id = $1 ORDER BY created_at ASC, id ASC LIMIT 100`, [card.id],
  )).map((e) => ({ ...e, data: typeof e.data === "string" ? JSON.parse(e.data) : e.data }));
  const spent = purchases.filter((a) => a.status === "held" || a.status === "settled").reduce((n, a) => n + a.amount_cents, 0);
  const first = card.recipient_name.split(" ")[0];
  const sentAt = events.find((e) => e.type === "card_link_copied")?.created_at;
  const status = CARD_STATUS[card.status];

  const text: Record<string, (d: any) => string> = {
    card_created: () => `Card created by ${club.treasurer}`,
    card_link_copied: (d) => `Link copied to send to ${d.to ?? card.recipient_contact}`,
    card_link_opened: () => `${first} opened the link`,
    card_link_replaced: () => "New link made; the old one stopped working",
    purchase_approved: (d) => `${fmt(d.amount_cents)} at ${d.merchant} approved`,
    purchase_declined: (d) => `${fmt(d.amount_cents)} at ${d.merchant} declined: ${reasonText(d.reason, card.limit_cents)}`,
    card_cancelled: () => `Card cancelled by ${club.treasurer}`,
    card_expired_unused: () => "Card expired without being used",
    settlement_simulated: (d) => `${fmt(d.amount_cents)} settled (club debit simulated in sandbox)`,
    hold_released: (d) => `${fmt(d.amount_cents)} hold released`,
  };

  return (
    <>
      <div className="page-head">
        <div>
          <Link className="crumb" href="/cards">Cards ›</Link>
          <div className="title-row">
            <h1>{card.purpose}</h1>
            <span className={`pill ${status.tone}`}>{status.label}</span>
          </div>
        </div>
        {card.status === "open" && <CardActions cardId={card.id} officer={first} />}
      </div>

      <dl className="facts">
        <div><dt>Limit</dt><dd>{fmt(card.limit_cents)}, one purchase</dd></div>
        <div><dt>Spent</dt><dd>{fmt(spent)}</dd></div>
        <div><dt>Card</dt><dd>••{card.last4}</dd></div>
        <div><dt>Sent to</dt><dd>{card.recipient_name} · {card.recipient_contact}</dd></div>
        <div><dt>Sent</dt><dd>{sentAt ? `${when(sentAt)} by link` : "Link not copied yet"}</dd></div>
        <div><dt>{card.status === "expired" ? "Expired" : "Expires"}</dt><dd>{day(card.expires_at)}</dd></div>
      </dl>

      <section className="panel" aria-labelledby="p-h">
        <div className="panel-head"><h2 id="p-h">Purchases</h2></div>
        {purchases.length === 0 ? (
          <p className="panel-empty">No purchases yet</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead><tr><th>When</th><th>Store</th><th className="r">Amount</th><th>Status</th><th>Reason</th></tr></thead>
              <tbody>
                {purchases.map((p) => (
                  <tr key={p.id}>
                    <td>{whenShort(p.created_at)}</td>
                    <td className="strong">{p.merchant}</td>
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

      <section className="panel" aria-labelledby="a-h">
        <div className="panel-head"><h2 id="a-h">Activity</h2></div>
        <div className="table-wrap">
          <table className="activity">
            <tbody>
              {events.map((e, i) => (
                <tr key={i}>
                  <td>{when(e.created_at)}</td>
                  <td className="wrap">{(text[e.type] ?? (() => e.type.replace(/_/g, " ")))(e.data)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
