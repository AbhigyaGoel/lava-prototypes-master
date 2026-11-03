"use client";
import { useMemo, useState } from "react";
import Link from "next/link";
import { post } from "./api";
import { VirtualCard } from "./VirtualCard";
import { CopyLink } from "./CopyLink";

const EXPIRY = [
  { days: 1, label: "In 24 hours" },
  { days: 3, label: "In 3 days" },
  { days: 7, label: "In 7 days" },
  { days: 14, label: "In 14 days" },
];

function toCents(v: string) {
  const n = Number(v.replace(/[$,\s]/g, ""));
  return Number.isFinite(n) && n > 0 ? Math.round(n * 100) : 0;
}
function money(c: number) {
  return (c / 100).toLocaleString("en-US", { style: "currency", currency: "USD" });
}
function short(c: number) {
  return c % 100 === 0 ? `$${(c / 100).toLocaleString("en-US")}` : money(c);
}

export function NewCardForm({ clubName, availableCents }: { clubName: string; availableCents: number }) {
  const [amount, setAmount] = useState("");
  const [purpose, setPurpose] = useState("");
  const [name, setName] = useState("");
  const [contact, setContact] = useState("");
  const [days, setDays] = useState(7);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [made, setMade] = useState<{ cardId: string; link: string } | null>(null);

  const cents = toCents(amount);
  const over = cents > availableCents;
  const expires = useMemo(
    () => new Date(Date.now() + days * 864e5).toLocaleDateString("en-US", { month: "short", day: "numeric" }),
    [days],
  );
  const firstName = name.trim().split(/\s+/)[0];
  const first = firstName || "The officer";
  const them = firstName || "the officer";
  const ready = cents > 0 && !over && purpose.trim() && name.trim() && contact.trim();

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!ready) return;
    setBusy(true); setError(null);
    try {
      setMade(await post("/api/cards", { amount, purpose, recipientName: name, recipientContact: contact, expiryDays: days }));
    } catch (err: any) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  const preview = (
    <VirtualCard
      clubName={clubName}
      corner="Virtual · single use"
      meta={[
        { label: "For", value: purpose.trim() || "—" },
        { label: "Limit", value: short(cents) },
        { label: "Expires", value: expires },
      ]}
      label={`Preview: ${clubName} card for ${purpose || "a purpose"}, limit ${money(cents)}, expires ${expires}`}
    />
  );

  return (
    <div className="new-card">
      {made ? (
        <div className="stack">
          <h2>Card created</h2>
          <p className="muted">Send {them} this link by email or text ({contact}). It opens the card; no app or account needed.</p>
          <CopyLink cardId={made.cardId} link={made.link} />
          <p className="caption">
            Anyone with the link can see the card until it's used, cancelled or expires. We only show the link once; you can make a new one from the card page.
          </p>
          <div className="actions">
            <Link className="btn" href={`/cards/${made.cardId}`}>Go to card</Link>
            <a className="btn secondary" href={made.link} target="_blank" rel="noreferrer">Open officer view</a>
          </div>
        </div>
      ) : (
        <form onSubmit={submit} noValidate>
          <div className="field">
            <label htmlFor="amount">Amount</label>
            <input id="amount" inputMode="decimal" placeholder="$700.00" value={amount}
              onChange={(e) => setAmount(e.target.value)} aria-describedby="amount-hint" aria-invalid={over} required />
            <span id="amount-hint" className={over ? "hint error" : "hint"} role={over ? "alert" : undefined}>
              {over ? `Max ${money(availableCents)} available` : `Up to ${money(availableCents)} available`}
            </span>
          </div>
          <div className="field">
            <label htmlFor="purpose">What it's for</label>
            <input id="purpose" placeholder="GBM food" maxLength={40} value={purpose} onChange={(e) => setPurpose(e.target.value)} required />
          </div>
          <div className="pair">
            <div className="field">
              <label htmlFor="name">Send to</label>
              <input id="name" placeholder="Jordan Lee" autoComplete="off" value={name} onChange={(e) => setName(e.target.value)} required />
            </div>
            <div className="field">
              <label htmlFor="contact">Email or phone</label>
              <input id="contact" placeholder="jordan@usc.edu" autoComplete="off" value={contact} onChange={(e) => setContact(e.target.value)} required />
            </div>
          </div>
          <div className="field">
            <label htmlFor="expiry">Expires</label>
            <select id="expiry" value={days} onChange={(e) => setDays(Number(e.target.value))}>
              {EXPIRY.map((o) => <option key={o.days} value={o.days}>{o.label}</option>)}
            </select>
          </div>
          {error && <p className="notice error" role="alert">{error}</p>}
          <div className="actions" style={{ gap: 16 }}>
            <button className="btn" disabled={busy || !ready}>{busy ? "Creating…" : "Create card"}</button>
            <Link className="btn secondary" href="/cards">Cancel</Link>
          </div>
        </form>
      )}

      <div className="preview">
        <h2>Preview</h2>
        {preview}
        <div className="infobox">
          <p>
            {first} can spend up to <b>{short(cents)}</b> once, before <b>{expires}</b>. Then the card closes.{" "}
            {made ? `Copy the link above and send it to ${them}.` : `You'll get a link to send ${them}.`}
          </p>
        </div>
      </div>
    </div>
  );
}
