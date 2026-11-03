import { getDb } from "@/lib/db";
import { cardIssuer } from "@/lib/providers/issuer";
import { REASON_TEXT, type DeclineReason } from "@/lib/decide";
import { parseDollars } from "@/lib/money";
import { UserError } from "@/lib/cards";
import { fail, ok } from "@/lib/http";

/**
 * Sandbox-only stand-in for a real store's checkout (the demo's "Raising Cane's" page).
 * The typed card number passes through here ONLY because this is a test checkout;
 * in production the merchant's payment processor handles it and Unifi never sees it.
 */
export async function POST(req: Request) {
  if (process.env.LITHIC_ENV === "production") return ok({ error: "not available" }, 404);
  try {
    const b = await req.json().catch(() => ({}));
    const amountCents = parseDollars(b.amount);
    if (!amountCents) throw new UserError("Enter an amount");
    if (String(b.pan ?? "").replace(/\D/g, "").length < 12) throw new UserError("Enter the card number");

    const db = await getDb();
    const { txnToken } = await cardIssuer(db).simulatePurchase({
      pan: String(b.pan), amountCents, merchant: String(b.merchant || "Raising Cane's"),
    });
    const [a] = txnToken
      ? await db.query<{ decision: string; decline_reason: DeclineReason | null }>(
          `SELECT decision, decline_reason FROM authorizations WHERE lithic_txn_token = $1`, [txnToken])
      : [];
    if (!a) return ok({ decision: "DECLINED", reason: "The card was declined" });
    return ok({ decision: a.decision, reason: a.decline_reason ? REASON_TEXT[a.decline_reason] : null });
  } catch (e) { return fail(e); }
}
