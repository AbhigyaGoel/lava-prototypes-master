import type { Metadata } from "next";
import { getDb } from "@/lib/db";
import { hashToken } from "@/lib/crypto";
import { logEvent, type CardRow } from "@/lib/ledger";
import { mode } from "@/lib/config";
import { fmt } from "@/lib/money";
import { day } from "@/lib/format";
import { dollarsShort } from "@/lib/display";
import { cardIssuer } from "@/lib/providers/issuer";
import { VirtualCard } from "@/components/VirtualCard";
import { CopyButton } from "@/components/CopyButton";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Your club card", robots: { index: false } };

export default async function OfficerCard({ params }: { params: Promise<{ token: string }> }) {
  const db = await getDb();
  const [card] = await db.query<CardRow & { club_name: string }>(
    `SELECT c.*, cl.name AS club_name FROM cards c JOIN clubs cl ON cl.id = c.club_id WHERE c.link_token_hash = $1`,
    [hashToken((await params).token)],
  );

  if (!card) {
    return (
      <Frame>
        <div className="officer-copy" style={{ textAlign: "center" }}>
          <h1>This link doesn't work</h1>
          <p className="muted">It may have been replaced. Ask your treasurer to send it again.</p>
        </div>
      </Frame>
    );
  }

  // FR-14: the link dies when the card closes.
  const closed = card.status !== "open" || new Date(card.expires_at) <= new Date();
  if (!closed) {
    const [seen] = await db.query(`SELECT 1 FROM events WHERE card_id = $1 AND type = 'card_link_opened' LIMIT 1`, [card.id]);
    if (!seen) await logEvent(db, { clubId: card.club_id, cardId: card.id, type: "card_link_opened", actor: "officer" });
  }
  const view = closed ? null : await cardIssuer(db).officerView(card);
  const limit = dollarsShort(card.limit_cents);

  return (
    <Frame>
      <div className="officer">
        <div className="officer-copy">
          {closed ? (
            <>
              <h1>This card has closed</h1>
              <p className="muted">
                It was used, cancelled or expired, so the card details are gone. Ask your treasurer if you need a new one.
              </p>
            </>
          ) : (
            <>
              <h1>{`${card.club_name} sent you a card`}</h1>
              <p className="muted">
                For <b>{card.purpose}</b> · up to <b>{fmt(card.limit_cents)}</b>, one purchase · expires {day(card.expires_at)}
              </p>
              <div className="infobox">
                <h2>How to use it</h2>
                <ol>
                  <li>Pay online and enter this card at checkout.</li>
                  <li>It works once, for up to {limit}.</li>
                  <li>Then it closes. Nothing to pay back.</li>
                </ol>
              </div>
              <p className="caption">Card details are shown by the card issuer and never stored on Unifi's servers.</p>
            </>
          )}
        </div>

        <div className="officer-card">
          {closed ? (
            <VirtualCard variant="closed" clubName={card.club_name} corner="Closed" last4={card.last4}
              meta={[{ label: "For", value: card.purpose }, { label: "Limit", value: limit }]}
              label={`${card.club_name} card ending ${card.last4}, closed`} />
          ) : view?.kind === "embed" ? (
            // Live mode: number, expiry and code are rendered by Lithic inside this iframe. Its copy buttons come from the embed.
            <iframe className="embed-frame" src={view.url} title="Card number, expiry and security code" allow="clipboard-write" />
          ) : view?.kind === "mock" ? (
            <>
              <VirtualCard variant="live" clubName={card.club_name} corner="Shown by the card issuer" pan={view.pan}
                meta={[{ label: "Expires", value: view.exp }, { label: "Code", value: view.cvv }, { label: "Limit", value: limit }]}
                label={`${card.club_name} card for ${card.purpose}`} />
              <div className="copy-row">
                <CopyButton value={view.pan} label="Copy number" />
                <CopyButton value={view.exp} label="Copy expiry" />
                <CopyButton value={view.cvv} label="Copy code" />
              </div>
            </>
          ) : null}
        </div>
      </div>
    </Frame>
  );
}

function Frame({ children }: { children: React.ReactNode }) {
  return (
    <div className="solo">
      {mode() === "mock" && <div className="sandbox-band">Test card. It only works at the Unifi test checkout.</div>}
      <header className="solo-top">
        <span className="brand"><span className="brand-mark" aria-hidden />Unifi</span>
        <span className="caption">No app needed</span>
      </header>
      <div className="solo-body">{children}</div>
    </div>
  );
}
