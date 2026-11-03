import type { Db } from "./db";
import { BALANCE_MAX_AGE_MS } from "./config";
import { id } from "./crypto";
import { bankForClub, committedCents, logEvent, type CardRow } from "./ledger";

export type DeclineReason =
  | "UNKNOWN_CARD"
  | "CARD_NOT_OPEN"
  | "CARD_EXPIRED"
  | "OVER_CARD_LIMIT"
  | "BANK_DISCONNECTED"
  | "BALANCE_STALE"
  | "CLUB_BALANCE_TOO_LOW"
  | "INTERNAL_ERROR";

export const REASON_TEXT: Record<DeclineReason, string> = {
  UNKNOWN_CARD: "Card not recognized",
  CARD_NOT_OPEN: "Card already used or closed",
  CARD_EXPIRED: "Card expired",
  OVER_CARD_LIMIT: "Over the card limit",
  BANK_DISCONNECTED: "Bank connection needs fixing",
  BALANCE_STALE: "Couldn't confirm the club balance",
  CLUB_BALANCE_TOO_LOW: "Club balance too low",
  INTERNAL_ERROR: "Unifi couldn't check this purchase",
};

export type AuthRequest = {
  txnToken: string;   // Lithic transaction token; our idempotency key
  cardToken: string;  // Lithic card token
  amountCents: number;
  merchant: string;
};

export type Decision = {
  decision: "APPROVED" | "DECLINED";
  reason: DeclineReason | null;
  authorizationId: string | null;
};

/**
 * The core feature. Called once per purchase attempt (Lithic ASA).
 * Reads only our own database: no vendor calls, so it answers well under a second.
 * Every failure path declines.
 */
export async function decide(db: Db, req: AuthRequest, now: Date = new Date()): Promise<Decision> {
  try {
    if (!Number.isInteger(req.amountCents) || req.amountCents <= 0) throw new Error("bad amount");

    return await db.tx(async (t) => {
      const [card] = await t.query<CardRow>(`SELECT * FROM cards WHERE lithic_card_token = $1`, [req.cardToken]);

      // Lock the club's bank row. All purchases for one club now run one at a time,
      // so two cards can't both spend the last dollars (T8), and a retried request
      // waits for the first and then sees its answer (T9).
      const bank = card ? await bankForClub(t, card.club_id, true) : null;

      const [prior] = await t.query<{ id: string; decision: Decision["decision"]; decline_reason: DeclineReason | null }>(
        `SELECT id, decision, decline_reason FROM authorizations WHERE lithic_txn_token = $1`,
        [req.txnToken],
      );
      if (prior) return { decision: prior.decision, reason: prior.decline_reason, authorizationId: prior.id };

      let reason: DeclineReason | null = null;
      if (!card) reason = "UNKNOWN_CARD";
      else if (card.status !== "open") reason = "CARD_NOT_OPEN";
      else if (new Date(card.expires_at) <= now) reason = "CARD_EXPIRED";
      else if (req.amountCents > card.limit_cents) reason = "OVER_CARD_LIMIT"; // no partial approvals
      else if (!bank || bank.status !== "connected") reason = "BANK_DISCONNECTED";
      else if (now.getTime() - new Date(bank.balance_refreshed_at).getTime() > BALANCE_MAX_AGE_MS) reason = "BALANCE_STALE";
      else {
        const committed = await committedCents(t, card.club_id);
        if (req.amountCents > bank.available_cents - committed) reason = "CLUB_BALANCE_TOO_LOW";
      }

      const approved = reason === null;
      const authId = id("auth");
      await t.query(
        `INSERT INTO authorizations
           (id, card_id, club_id, lithic_txn_token, amount_cents, merchant, decision, decline_reason, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [authId, card?.id ?? null, card?.club_id ?? null, req.txnToken, req.amountCents, req.merchant,
         approved ? "APPROVED" : "DECLINED", reason, approved ? "held" : "declined"],
      );
      if (approved) await t.query(`UPDATE cards SET status = 'used' WHERE id = $1`, [card!.id]); // single use

      await logEvent(t, {
        clubId: card?.club_id, cardId: card?.id, actor: "issuer",
        type: approved ? "purchase_approved" : "purchase_declined",
        data: { amount_cents: req.amountCents, merchant: req.merchant, reason },
      });

      return { decision: approved ? "APPROVED" : "DECLINED", reason, authorizationId: authId };
    });
  } catch (err) {
    console.error("[decide] failing closed:", err);
    return { decision: "DECLINED", reason: "INTERNAL_ERROR", authorizationId: null };
  }
}

/** Clearing settles a hold; a void/reversal releases it (Lithic transaction events). */
export async function settleOrRelease(db: Db, txnToken: string, outcome: "settled" | "released") {
  await db.tx(async (t) => {
    const rows = await t.query<{ id: string; club_id: string; card_id: string; amount_cents: number }>(
      `UPDATE authorizations SET status = $2, updated_at = now()
       WHERE lithic_txn_token = $1 AND status = 'held'
       RETURNING id, club_id, card_id, amount_cents`,
      [txnToken, outcome],
    );
    for (const r of rows) {
      await logEvent(t, {
        clubId: r.club_id, cardId: r.card_id, actor: "issuer",
        type: outcome === "settled" ? "settlement_simulated" : "hold_released",
        data: { amount_cents: r.amount_cents, note: outcome === "settled" ? "club account debit simulated (sandbox)" : undefined },
      });
    }
  });
}
