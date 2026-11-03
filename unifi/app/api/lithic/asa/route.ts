import { NextResponse } from "next/server";
import { getDb } from "@/lib/db";
import { decide, type DeclineReason } from "@/lib/decide";
import { logEvent } from "@/lib/ledger";
import { verifyAsaSignature } from "@/lib/providers/issuer";

/**
 * Lithic Auth Stream Access: Lithic asks us to approve or decline each purchase.
 * Week-1 checks: Lithic's ASA timeout, what it does with no answer (set the program to decline),
 * and which `result` codes ASA responses accept.
 */
const DECISION_BUDGET_MS = 800;

const RESULT_FOR: Record<DeclineReason, string> = {
  UNKNOWN_CARD: "CARD_CLOSED",
  CARD_NOT_OPEN: "CARD_CLOSED",
  CARD_EXPIRED: "CARD_CLOSED",
  OVER_CARD_LIMIT: "USER_TRANSACTION_LIMIT",
  BANK_DISCONNECTED: "INSUFFICIENT_FUNDS",
  BALANCE_STALE: "INSUFFICIENT_FUNDS",
  CLUB_BALANCE_TOO_LOW: "INSUFFICIENT_FUNDS",
  INTERNAL_ERROR: "UNAUTHORIZED_MERCHANT",
};

export async function POST(req: Request) {
  const raw = await req.text();
  let token: string | undefined;
  try {
    if (!verifyAsaSignature(raw, req.headers.get("x-lithic-hmac"))) {
      return NextResponse.json({ error: "bad signature" }, { status: 401 }); // Lithic treats non-2xx as a decline
    }
    const body = JSON.parse(raw);
    token = body.token;
    const db = await getDb();
    const amountCents = Number(body.authorization_amount ?? body.amount);
    const merchant = String(body.merchant?.descriptor ?? "Unknown store");
    const cardToken = String(body.card?.token ?? body.card_token ?? "");

    // Refunds come through as credit authorizations: accept, record, no hold.
    if (String(body.status ?? "").includes("CREDIT")) {
      await logEvent(db, { type: "refund_received", actor: "issuer", data: { amount_cents: amountCents, merchant, card_token: cardToken } });
      return NextResponse.json({ token, result: "APPROVED" });
    }

    const timeout = new Promise<{ decision: "DECLINED"; reason: DeclineReason }>((r) =>
      setTimeout(() => r({ decision: "DECLINED", reason: "INTERNAL_ERROR" }), DECISION_BUDGET_MS));
    const d = await Promise.race([decide(db, { txnToken: String(token), cardToken, amountCents, merchant }), timeout]);

    return NextResponse.json({ token, result: d.decision === "APPROVED" ? "APPROVED" : RESULT_FOR[d.reason!] });
  } catch (e) {
    console.error("[asa] failing closed", e);
    return NextResponse.json({ token, result: "UNAUTHORIZED_MERCHANT" });
  }
}
