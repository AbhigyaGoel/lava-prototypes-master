import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { createPgliteDb, type Db } from "@/lib/db";
import { seed, CLUB_ID } from "@/lib/seed";
import { decide, settleOrRelease } from "@/lib/decide";
import { clubSummary } from "@/lib/ledger";

// Acceptance tests T4–T11 from the build spec, against the real decision engine and a real
// Postgres (PGlite, in memory). Club balance starts at $1,240, like the wireframes.

let db: Db;
const NOW = new Date("2026-11-20T18:00:00Z");
let n = 0;

async function bank(availableCents = 124000, refreshedAt = NOW, status = "connected") {
  await db.query(
    `INSERT INTO bank_accounts (id, club_id, plaid_access_token, plaid_account_id, institution_name,
       account_name, mask, available_cents, balance_refreshed_at, status)
     VALUES ('bank_1', $1, 'x', 'acc', 'USC Credit Union', 'Cardinal Checking', '4821', $2, $3, $4)
     ON CONFLICT (club_id) DO UPDATE SET available_cents = $2, balance_refreshed_at = $3, status = $4`,
    [CLUB_ID, availableCents, refreshedAt, status],
  );
}

async function card(limitCents = 70000, opts: { status?: string; expiresAt?: Date } = {}) {
  const i = ++n;
  await db.query(
    `INSERT INTO cards (id, club_id, lithic_card_token, last4, purpose, limit_cents, recipient_name,
       recipient_contact, link_token_hash, status, expires_at)
     VALUES ($1, $2, $3, '4417', 'GBM food', $4, 'Jordan Lee', 'jordan@usc.edu', $5, $6, $7)`,
    [`card_${i}`, CLUB_ID, `lithic_${i}`, limitCents, `hash_${i}`, opts.status ?? "open",
     opts.expiresAt ?? new Date(NOW.getTime() + 7 * 864e5)],
  );
  return `lithic_${i}`;
}

const buy = (cardToken: string, amountCents: number, txnToken = `txn_${++n}`) =>
  decide(db, { txnToken, cardToken, amountCents, merchant: "RAISING CANES #123" }, NOW);

beforeEach(async () => {
  db = await createPgliteDb();
  await seed(db);
  await bank();
});
afterEach(async () => db.close());

describe("decision engine", () => {
  it("T4: approves a purchase under the limit, holds it, and closes the card", async () => {
    const c = await card(70000);
    const r = await buy(c, 61200);
    expect(r).toMatchObject({ decision: "APPROVED", reason: null });
    const [row] = await db.query(`SELECT status FROM cards WHERE lithic_card_token = $1`, [c]);
    expect(row.status).toBe("used");
    const s = await clubSummary(db, CLUB_ID);
    expect(s.spendableCents).toBe(124000 - 61200);
  });

  it("T5: declines a second purchase on a single-use card", async () => {
    const c = await card(70000);
    await buy(c, 61200);
    expect(await buy(c, 500)).toMatchObject({ decision: "DECLINED", reason: "CARD_NOT_OPEN" });
  });

  it("T6: declines one cent over the card limit, with no partial approval", async () => {
    const c = await card(70000);
    expect(await buy(c, 70001)).toMatchObject({ decision: "DECLINED", reason: "OVER_CARD_LIMIT" });
    expect(await buy(c, 70000)).toMatchObject({ decision: "APPROVED" });
  });

  it("T7: declines when the club balance dropped after the card was made", async () => {
    const c = await card(70000);
    await bank(50000);
    expect(await buy(c, 60000)).toMatchObject({ decision: "DECLINED", reason: "CLUB_BALANCE_TOO_LOW" });
  });

  it("T8: two cards racing for the same money: exactly one is approved", async () => {
    await bank(100000);
    const [a, b] = [await card(70000), await card(70000)];
    const results = await Promise.all([buy(a, 70000), buy(b, 70000)]);
    expect(results.filter((r) => r.decision === "APPROVED")).toHaveLength(1);
    expect(results.find((r) => r.decision === "DECLINED")?.reason).toBe("CLUB_BALANCE_TOO_LOW");
  });

  it("T9: a retried request gets the same answer and only one hold", async () => {
    const c = await card(70000);
    const first = await buy(c, 30000, "txn_retry");
    const again = await buy(c, 30000, "txn_retry");
    expect(again).toEqual(first);
    const [r] = await db.query(`SELECT COUNT(*)::int AS n FROM authorizations WHERE status = 'held'`);
    expect(r.n).toBe(1);
  });

  it("T10: declines when the cached balance is older than 15 minutes", async () => {
    const c = await card(70000);
    await bank(124000, new Date(NOW.getTime() - 16 * 60_000));
    expect(await buy(c, 1000)).toMatchObject({ decision: "DECLINED", reason: "BALANCE_STALE" });
  });

  it("T11: declines if anything inside the engine throws", async () => {
    const c = await card(70000);
    const broken: Db = { ...db, tx: async () => { throw new Error("db down"); } };
    const r = await decide(broken, { txnToken: "t", cardToken: c, amountCents: 100, merchant: "X" }, NOW);
    expect(r).toMatchObject({ decision: "DECLINED", reason: "INTERNAL_ERROR" });
  });

  it("declines expired, cancelled, unknown cards and a broken bank connection", async () => {
    expect(await buy(await card(70000, { expiresAt: new Date(NOW.getTime() - 1) }), 100))
      .toMatchObject({ reason: "CARD_EXPIRED" });
    expect(await buy(await card(70000, { status: "cancelled" }), 100)).toMatchObject({ reason: "CARD_NOT_OPEN" });
    expect(await buy("nope", 100)).toMatchObject({ reason: "UNKNOWN_CARD" });
    const c = await card(70000);
    await bank(124000, NOW, "broken");
    expect(await buy(c, 100)).toMatchObject({ reason: "BANK_DISCONNECTED" });
  });

  it("settled purchases keep counting against the balance; voided ones free it", async () => {
    const [a, b] = [await card(70000), await card(30000)];
    await buy(a, 50000, "txn_a");
    await buy(b, 20000, "txn_b");
    await settleOrRelease(db, "txn_a", "settled");
    await settleOrRelease(db, "txn_b", "released");
    expect((await clubSummary(db, CLUB_ID)).spendableCents).toBe(124000 - 50000);
  });
});
