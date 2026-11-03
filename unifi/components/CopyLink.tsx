"use client";
import { useState } from "react";

/** The MVP's "Send" step (spec FR-12, faked): copy the officer link and record that it went out. */
export function CopyLink({ cardId, link }: { cardId: string; link: string }) {
  const [done, setDone] = useState(false);
  return (
    <div className="linkbox">
      <input readOnly value={link} aria-label="Officer link" onFocus={(e) => e.currentTarget.select()} />
      <button type="button" className="btn" onClick={async () => {
        await navigator.clipboard.writeText(link).catch(() => {});
        setDone(true);
        setTimeout(() => setDone(false), 1600);
        fetch(`/api/cards/${cardId}/sent`, { method: "POST" }).catch(() => {});
      }}>
        {done ? "Copied" : "Copy link"}
      </button>
    </div>
  );
}
