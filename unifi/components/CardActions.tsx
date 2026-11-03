"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { post } from "./api";
import { CopyLink } from "./CopyLink";

/**
 * Frame 5 actions for an open card. "Resend link": we only keep the link's hash, so resending
 * makes a fresh link (the old one stops working) for the treasurer to copy and send.
 */
export function CardActions({ cardId, officer }: { cardId: string; officer: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState<"link" | "cancel" | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [link, setLink] = useState<string | null>(null);

  async function resend() {
    setBusy("link"); setError(null);
    try { setLink((await post<{ link: string }>(`/api/cards/${cardId}/link`)).link); router.refresh(); }
    catch (e: any) { setError(e.message); }
    finally { setBusy(null); }
  }

  async function cancel() {
    setBusy("cancel"); setError(null);
    try { await post(`/api/cards/${cardId}/cancel`); router.refresh(); }
    catch (e: any) { setError(e.message); setBusy(null); }
  }

  return (
    <div className="stack" style={{ gap: 12, alignItems: "flex-end", maxWidth: "100%" }}>
      {confirming ? (
        <div className="actions" role="group" aria-label="Confirm cancel">
          <span className="muted" style={{ alignSelf: "center" }}>Cancel this card? Any purchase on it will decline.</span>
          <button className="btn" onClick={cancel} disabled={!!busy}>{busy === "cancel" ? "Cancelling…" : "Yes, cancel card"}</button>
          <button className="btn secondary" onClick={() => setConfirming(false)} disabled={!!busy}>Keep it</button>
        </div>
      ) : (
        <div className="actions">
          <button className="btn secondary" onClick={resend} disabled={!!busy}>{busy === "link" ? "Making link…" : "Resend link"}</button>
          <button className="btn dashed" onClick={() => setConfirming(true)} disabled={!!busy}>Cancel card</button>
        </div>
      )}
      {link && (
        <div className="stack" style={{ gap: 6, width: "min(460px, 100%)" }}>
          <CopyLink cardId={cardId} link={link} />
          <span className="caption">New link for {officer}. The old link no longer works.</span>
        </div>
      )}
      {error && <p className="notice error" role="alert">{error}</p>}
    </div>
  );
}
