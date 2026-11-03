import { getDb } from "@/lib/db";
import { refreshBalance } from "@/lib/cards";
import { cronAllowed, fail, ok } from "@/lib/http";

// Keeps every club's cached balance younger than the 15-minute limit the decision engine enforces.
export async function GET(req: Request) {
  if (!cronAllowed(req)) return ok({ error: "unauthorized" }, 401);
  try {
    const db = await getDb();
    const clubs = await db.query<{ club_id: string }>(`SELECT club_id FROM bank_accounts`);
    for (const c of clubs) await refreshBalance(db, c.club_id);
    return ok({ refreshed: clubs.length });
  } catch (e) { return fail(e); }
}
