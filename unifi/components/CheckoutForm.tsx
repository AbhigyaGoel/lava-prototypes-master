"use client";
import { useState } from "react";
import { post } from "./api";

type Result = { decision: "APPROVED" | "DECLINED"; reason: string | null };

export function CheckoutForm() {
  const [merchant, setMerchant] = useState("Raising Cane's");
  const [amount, setAmount] = useState("612.40");
  const [pan, setPan] = useState("");
  const [exp, setExp] = useState("");
  const [cvv, setCvv] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<Result | null>(null);

  async function pay(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null); setResult(null);
    try { setResult(await post<Result>("/api/dev/simulate", { merchant, amount, pan })); }
    catch (err: any) { setError(err.message); }
    finally { setBusy(false); }
  }

  return (
    <form className="checkout" onSubmit={pay}>
      <div className="store-head">
        <span className="logo" aria-hidden>{merchant.trim().slice(0, 1) || "?"}</span>
        <div>
          <h1 style={{ fontSize: 22, lineHeight: "28px" }}>{merchant || "Store"}</h1>
          <span className="caption">Checkout</span>
        </div>
      </div>
      <div className="pair">
        <div className="field">
          <label htmlFor="m">Store</label>
          <input id="m" value={merchant} onChange={(e) => setMerchant(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="a">Order total</label>
          <input id="a" inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} />
        </div>
      </div>
      <div className="field">
        <label htmlFor="pan">Card number</label>
        <input id="pan" inputMode="numeric" autoComplete="off" placeholder="Paste from the card page" value={pan} onChange={(e) => setPan(e.target.value)} />
      </div>
      <div className="pair">
        <div className="field"><label htmlFor="exp">Expiry</label><input id="exp" placeholder="MM/YY" value={exp} onChange={(e) => setExp(e.target.value)} /></div>
        <div className="field"><label htmlFor="cvv">Security code</label><input id="cvv" inputMode="numeric" placeholder="123" value={cvv} onChange={(e) => setCvv(e.target.value)} /></div>
      </div>
      {error && <p className="notice error" role="alert">{error}</p>}
      <button className="btn block" disabled={busy}>{busy ? "Paying…" : `Pay $${amount || "0"}`}</button>
      {result && (
        <div className={`result ${result.decision === "APPROVED" ? "approved" : "declined"}`} role="status">
          <span className="big">{result.decision === "APPROVED" ? "Purchase approved" : "Card declined"}</span>
          <span>{result.decision === "APPROVED" ? "Order placed. The card is now closed." : result.reason}</span>
        </div>
      )}
    </form>
  );
}
