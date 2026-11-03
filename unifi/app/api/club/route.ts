import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { UserError } from "@/lib/cards";
import { logEvent } from "@/lib/ledger";
import { fail, ok } from "@/lib/http";

// Club profile (frame 2): name, and an EIN that's optional for now.
export async function POST(req: Request) {
  try {
    const b = await req.json().catch(() => ({}));
    const name = String(b.name ?? "").trim();
    const ein = String(b.ein ?? "").trim();
    if (!name) throw new UserError("Enter the club's name");
    if (name.length > 80) throw new UserError("Keep the club name under 80 characters");
    if (ein && !/^\d{2}-?\d{7}$/.test(ein)) throw new UserError("An EIN looks like 12-3456789");
    const db = await getDb();
    await db.query(`UPDATE clubs SET name = $2, ein = $3 WHERE id = $1`, [CLUB_ID, name, ein || null]);
    await logEvent(db, { clubId: CLUB_ID, type: "club_profile_saved", actor: "treasurer" });
    return ok({ name, ein: ein || null });
  } catch (e) { return fail(e); }
}
