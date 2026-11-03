import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { mode } from "@/lib/config";
import { bankForClub } from "@/lib/ledger";
import { decrypt } from "@/lib/crypto";
import { refreshBalance, UserError } from "@/lib/cards";
import { parseDollars } from "@/lib/money";
import { fail, ok } from "@/lib/http";

/** Mock mode only: change the fake bank's balance to demo "Club balance too low". */
export async function POST(req: Request) {
  if (mode() !== "mock") return ok({ error: "mock mode only" }, 404);
  try {
    const b = await req.json().catch(() => ({}));
    const cents = parseDollars(b.amount);
    if (cents === null) throw new UserError("Enter an amount");
    const db = await getDb();
    const bank = await bankForClub(db, CLUB_ID);
    if (!bank) throw new UserError("Connect a bank first");
    await db.query(`UPDATE mock_bank SET available_cents = $2 WHERE access_token = $1`, [decrypt(bank.plaid_access_token), cents]);
    await refreshBalance(db, CLUB_ID);
    return ok({ availableCents: cents });
  } catch (e) { return fail(e); }
}
