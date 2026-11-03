import type { Queryable } from "./db";

export type PurchaseRow = {
  id: string;
  card_id: string | null;
  amount_cents: number;
  merchant: string;
  decision: "APPROVED" | "DECLINED";
  decline_reason: string | null;
  status: "held" | "settled" | "released" | "declined";
  created_at: Date;
  purpose: string | null;
  officer: string | null;
  limit_cents: number | null;
};

export type PurchaseFilters = {
  q?: string;
  decision?: "APPROVED" | "DECLINED";
  officer?: string;
  days?: number; // 0 or undefined = all time
  cardId?: string;
  limit?: number;
};

/** The purchase feed (FR-18): every authorization attempt with its card and officer. */
export async function listPurchases(q: Queryable, clubId: string, f: PurchaseFilters = {}): Promise<PurchaseRow[]> {
  const where = ["a.club_id = $1"];
  const params: unknown[] = [clubId];
  const add = (sql: string, v: unknown) => { params.push(v); where.push(sql.replace("?", `$${params.length}`)); };

  if (f.cardId) add("a.card_id = ?", f.cardId);
  if (f.decision) add("a.decision = ?", f.decision);
  if (f.officer) add("c.recipient_name = ?", f.officer);
  if (f.days) add("a.created_at >= now() - make_interval(days => ?::int)", f.days);
  if (f.q?.trim()) {
    params.push(`%${f.q.trim().toLowerCase()}%`);
    const p = `$${params.length}`;
    where.push(`(lower(a.merchant) LIKE ${p} OR lower(c.recipient_name) LIKE ${p} OR lower(c.purpose) LIKE ${p} OR c.last4 LIKE ${p})`);
  }
  params.push(f.limit ?? 500);

  return q.query<PurchaseRow>(
    `SELECT a.id, a.card_id, a.amount_cents, a.merchant, a.decision, a.decline_reason, a.status, a.created_at,
            c.purpose, c.recipient_name AS officer, c.limit_cents
     FROM authorizations a LEFT JOIN cards c ON c.id = a.card_id
     WHERE ${where.join(" AND ")}
     ORDER BY a.created_at DESC
     LIMIT $${params.length}`,
    params,
  );
}

export async function officerNames(q: Queryable, clubId: string): Promise<string[]> {
  const rows = await q.query<{ n: string }>(
    `SELECT DISTINCT recipient_name AS n FROM cards WHERE club_id = $1 ORDER BY 1`, [clubId]);
  return rows.map((r) => r.n);
}

export function parseFilters(sp: Record<string, string | string[] | undefined>): PurchaseFilters {
  const one = (k: string) => (Array.isArray(sp[k]) ? sp[k]![0] : sp[k]) as string | undefined;
  const status = one("status");
  const days = one("days");
  return {
    q: one("q") || undefined,
    decision: status === "approved" ? "APPROVED" : status === "declined" ? "DECLINED" : undefined,
    officer: one("officer") || undefined,
    days: days === "all" ? 0 : Number(days) || 30,
  };
}
