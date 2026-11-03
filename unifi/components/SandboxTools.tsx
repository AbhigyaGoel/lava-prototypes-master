"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { post } from "./api";

export function SandboxTools({ mock }: { mock: boolean }) {
  const router = useRouter();
  const [amount, setAmount] = useState("");
  const [msg, setMsg] = useState<string | null>(null);
  const run = (fn: () => Promise<unknown>, done: string) => async () => {
    setMsg(null);
    try { await fn(); setMsg(done); router.refresh(); } catch (e: any) { setMsg(e.message); }
  };
  return (
    <section className="tools" aria-labelledby="tools-h">
      <h2 id="tools-h">Demo tools</h2>
      <p className="caption">
        For rehearsals. Open the <a href="/checkout" target="_blank">test checkout</a> to spend a card.
      </p>
      <div className="row">
        <button className="btn secondary" onClick={run(() => post("/api/balance/refresh"), "Balance refreshed")}>Refresh balance</button>
        {mock && (
          <>
            <div className="field">
              <label htmlFor="setbal">Set fake bank balance</label>
              <input id="setbal" inputMode="decimal" placeholder="$500" value={amount} onChange={(e) => setAmount(e.target.value)} />
            </div>
            <button className="btn secondary" onClick={run(() => post("/api/dev/balance", { amount }), "Fake balance updated")}>Set</button>
          </>
        )}
      </div>
      {msg && <p className="caption" role="status">{msg}</p>}
    </section>
  );
}
