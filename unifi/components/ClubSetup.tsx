"use client";
import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { post } from "./api";

declare global {
  interface Window { Plaid?: { create(cfg: any): { open(): void } } }
}

function loadPlaid(): Promise<void> {
  if (window.Plaid) return Promise.resolve();
  return new Promise((resolve, reject) => {
    const s = document.createElement("script");
    s.src = "https://cdn.plaid.com/link/v2/stable/link-initialize.js";
    s.onload = () => resolve();
    s.onerror = () => reject(new Error("Couldn't load Plaid. Check your connection and try again."));
    document.head.appendChild(s);
  });
}

function money(c: number) {
  return (c / 100).toLocaleString("en-US", { style: "currency", currency: "USD" });
}

type Bank = { institution: string; account: string; mask: string; availableCents: number; broken: boolean } | null;

export function ClubSetup({ clubName, ein: initialEin, bank, next }: { clubName: string; ein: string; bank: Bank; next: string }) {
  const router = useRouter();
  const [name, setName] = useState(clubName);
  const [ein, setEin] = useState(initialEin);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [failedLogin, setFailedLogin] = useState(false);
  const [waitlist, setWaitlist] = useState(false);

  async function finish(publicToken: string | null, metadata: unknown) {
    await post("/api/plaid/exchange", { publicToken, metadata });
    setBusy(false);
    router.refresh();
  }

  async function connect() {
    setBusy(true); setError(null); setFailedLogin(false);
    try {
      await post("/api/club", { name, ein });
      const { linkToken } = await post<{ linkToken: string | null }>("/api/plaid/link-token");
      if (!linkToken) return await finish(null, {}); // mock mode: no Plaid window
      await loadPlaid();
      window.Plaid!.create({
        token: linkToken,
        onSuccess: (publicToken: string, metadata: unknown) =>
          finish(publicToken, metadata).catch((e) => { setError(e.message); setBusy(false); }),
        onExit: (err: { error_code?: string; display_message?: string } | null) => {
          if (err) {
            setFailedLogin(true);
            setError(err.display_message ?? "The bank login didn't go through.");
          }
          setBusy(false);
        },
      }).open();
    } catch (e: any) {
      setError(e.message); setBusy(false);
    }
  }

  async function saveAndContinue() {
    setBusy(true); setError(null);
    try {
      await post("/api/club", { name, ein });
      router.push(next);
    } catch (e: any) { setError(e.message); setBusy(false); }
  }

  const connectLabel = busy ? "Connecting…" : failedLogin ? "Try again" : bank?.broken ? "Reconnect with Plaid" : bank ? "Connect a different account" : "Connect with Plaid";

  return (
    <>
      <div className="pair">
        <div className="field">
          <label htmlFor="club">Club name</label>
          <input id="club" value={name} onChange={(e) => setName(e.target.value)} maxLength={80} />
        </div>
        <div className="field">
          <label htmlFor="ein">EIN (optional for now)</label>
          <input id="ein" placeholder="12-3456789" inputMode="numeric" value={ein} onChange={(e) => setEin(e.target.value)} />
        </div>
      </div>

      <div className="stack" style={{ gap: 10 }}>
        <div className="actions">
          <button className={bank && !bank.broken && !failedLogin ? "btn secondary" : "btn"} onClick={connect} disabled={busy || !name.trim()}>
            {connectLabel}
          </button>
        </div>
        {error && (
          <p className="notice error" role="alert">
            {failedLogin ? `${error} Check the username and password, then try again.` : error}
          </p>
        )}
        <p className="caption">We can read the balance. We never see your bank login.</p>
      </div>

      {bank && (
        <>
          <h2>{bank.broken ? "Needs reconnecting" : "Connected"}</h2>
          <div className="bank-card">
            <div className="who">
              <span className="logo" aria-hidden>{bank.institution.slice(0, 1)}</span>
              <div>
                <div className="name">{bank.institution}</div>
                <div className="muted">{bank.account} ••{bank.mask}</div>
              </div>
            </div>
            <div className="bal">
              <span className="muted">Available balance</span>
              <b>{money(bank.availableCents)}</b>
            </div>
          </div>
          {bank.broken && <p className="notice error">The bank asked for the login again. Reconnect to keep making cards.</p>}
          <div className="actions">
            <button className="btn" onClick={saveAndContinue} disabled={busy || bank.broken || !name.trim()}>Continue</button>
          </div>
        </>
      )}

      {!bank && (
        <div>
          {!waitlist ? (
            <button className="linkish" onClick={() => setWaitlist(true)}>My bank isn't listed</button>
          ) : (
            <Waitlist />
          )}
        </div>
      )}
      {bank && <p className="caption"><Link href={next}>Skip for now</Link></p>}
    </>
  );
}

function Waitlist() {
  const [bank, setBank] = useState("");
  const [email, setEmail] = useState("");
  const [state, setState] = useState<"idle" | "busy" | "done">("idle");
  const [error, setError] = useState<string | null>(null);

  if (state === "done") return <p className="notice ok" role="status">Thanks. We'll email {email} when {bank || "your bank"} is supported.</p>;

  return (
    <form className="stack" style={{ maxWidth: 660 }} onSubmit={async (e) => {
      e.preventDefault(); setState("busy"); setError(null);
      try { await post("/api/waitlist", { email, bank }); setState("done"); }
      catch (err: any) { setError(err.message); setState("idle"); }
    }}>
      <p className="notice warn">This bank isn't supported yet. Leave your email and we'll tell you when it is.</p>
      <div className="pair">
        <div className="field"><label htmlFor="wb">Bank</label><input id="wb" value={bank} onChange={(e) => setBank(e.target.value)} placeholder="Your bank's name" /></div>
        <div className="field"><label htmlFor="we">Email</label><input id="we" type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@usc.edu" /></div>
      </div>
      {error && <p className="notice error" role="alert">{error}</p>}
      <div className="actions"><button className="btn secondary" disabled={state === "busy"}>Join the waitlist</button></div>
    </form>
  );
}
