import { NextResponse } from "next/server";
import { getDb } from "@/lib/db";
import { settleOrRelease } from "@/lib/decide";
import { unwrapLithicEvent } from "@/lib/providers/issuer";

/** Transaction updates from Lithic: clearing settles a hold, a void releases it. */
export async function POST(req: Request) {
  const raw = await req.text();
  let event: any;
  try {
    event = await unwrapLithicEvent(raw, req.headers); // throws on a bad signature
  } catch {
    return NextResponse.json({ error: "bad signature" }, { status: 401 });
  }
  if (event?.event_type !== "card_transaction.updated") return NextResponse.json({ ignored: true });

  const txn = event.payload ?? event;
  const db = await getDb();
  if (txn.status === "SETTLED") await settleOrRelease(db, txn.token, "settled");
  if (txn.status === "VOIDED" || txn.status === "EXPIRED") await settleOrRelease(db, txn.token, "released");
  return NextResponse.json({ ok: true });
}
