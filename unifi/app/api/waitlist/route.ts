import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { UserError } from "@/lib/cards";
import { logEvent } from "@/lib/ledger";
import { fail, ok } from "@/lib/http";

// Frame 2 "Unsupported bank": collect an email for when the bank is supported. Stored as an event.
export async function POST(req: Request) {
  try {
    const b = await req.json().catch(() => ({}));
    const email = String(b.email ?? "").trim();
    const bank = String(b.bank ?? "").trim().slice(0, 80);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new UserError("Enter an email address");
    await logEvent(await getDb(), { clubId: CLUB_ID, type: "bank_waitlist_joined", actor: "treasurer", data: { email, bank } });
    return ok({ ok: true });
  } catch (e) { return fail(e); }
}
