import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { connectBank } from "@/lib/cards";
import { clubSummary } from "@/lib/ledger";
import { fail, ok } from "@/lib/http";

export async function POST(req: Request) {
  try {
    const { publicToken = null, metadata = {} } = await req.json().catch(() => ({}));
    const db = await getDb();
    await connectBank(db, CLUB_ID, publicToken, metadata);
    const s = await clubSummary(db, CLUB_ID);
    return ok({ institution: s.bank?.institution_name, mask: s.bank?.mask, availableCents: s.bank?.available_cents });
  } catch (e) { return fail(e); }
}
