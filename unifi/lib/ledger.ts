import type { Queryable } from "./db";

export type BankRow = {
  id: string;
  club_id: string;
  plaid_access_token: string;
  plaid_account_id: string;
  institution_name: string;
  account_name: string;
  mask: string;
  available_cents: number;
  balance_refreshed_at: Date;
  status: "connected" | "broken";
};

export type CardRow = {
  id: string;
  club_id: string;
  lithic_card_token: string;
  last4: string;
  purpose: string;
  limit_cents: number;
  recipient_name: string;
  recipient_contact: string;
  status: "open" | "used" | "cancelled" | "expired";
  expires_at: Date;
  created_at: Date;
};

export type AuthRow = {
  id: string;
  card_id: string | null;
  amount_cents: number;
  merchant: string;
  decision: "APPROVED" | "DECLINED";
  decline_reason: string | null;
  status: "held" | "settled" | "released" | "declined";
  created_at: Date;
};

/**
 * Money already promised from the club account:
 * approved purchases that are held, plus settled ones whose club debit is simulated
 * (in the sandbox it never reaches the bank, so the bank balance never drops).
 */
export async function committedCents(q: Queryable, clubId: string): Promise<number> {
  const [r] = await q.query<{ c: number }>(
    `SELECT COALESCE(SUM(amount_cents), 0)::int AS c FROM authorizations
     WHERE club_id = $1 AND status IN ('held', 'settled')`,
    [clubId],
  );
  return r.c;
}

export async function openLimitsCents(q: Queryable, clubId: string): Promise<{ cents: number; count: number }> {
  const [r] = await q.query<{ c: number; n: number }>(
    `SELECT COALESCE(SUM(limit_cents), 0)::int AS c, COUNT(*)::int AS n FROM cards
     WHERE club_id = $1 AND status = 'open'`,
    [clubId],
  );
  return { cents: r.c, count: r.n };
}

export async function bankForClub(q: Queryable, clubId: string, forUpdate = false): Promise<BankRow | null> {
  const rows = await q.query<BankRow>(
    `SELECT * FROM bank_accounts WHERE club_id = $1${forUpdate ? " FOR UPDATE" : ""}`,
    [clubId],
  );
  return rows[0] ?? null;
}

export type ClubSummary = {
  bank: BankRow | null;
  spendableCents: number;           // balance minus committed purchases
  availableForNewCardsCents: number; // spendable minus limits of open cards
  openCards: number;
  openLimitsCents: number;
};

export async function clubSummary(q: Queryable, clubId: string, forUpdate = false): Promise<ClubSummary> {
  const bank = await bankForClub(q, clubId, forUpdate);
  const committed = await committedCents(q, clubId);
  const open = await openLimitsCents(q, clubId);
  const spendable = bank ? bank.available_cents - committed : 0;
  return {
    bank,
    spendableCents: spendable,
    availableForNewCardsCents: Math.max(0, spendable - open.cents),
    openCards: open.count,
    openLimitsCents: open.cents,
  };
}

export async function logEvent(
  q: Queryable,
  e: { clubId?: string | null; cardId?: string | null; type: string; actor: string; data?: Record<string, unknown> },
) {
  await q.query(
    `INSERT INTO events (club_id, card_id, type, actor, data) VALUES ($1, $2, $3, $4, $5)`,
    [e.clubId ?? null, e.cardId ?? null, e.type, e.actor, JSON.stringify(e.data ?? {})],
  );
}
