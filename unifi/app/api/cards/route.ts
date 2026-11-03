import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { createCard, UserError } from "@/lib/cards";
import { parseDollars } from "@/lib/money";
import { fail, ok, originOf } from "@/lib/http";

export async function POST(req: Request) {
  try {
    const b = await req.json().catch(() => ({}));
    const limitCents = parseDollars(b.amount);
    if (!limitCents) throw new UserError("Enter an amount above $0");
    const card = await createCard(await getDb(), {
      clubId: CLUB_ID,
      limitCents,
      purpose: String(b.purpose ?? ""),
      recipientName: String(b.recipientName ?? ""),
      recipientContact: String(b.recipientContact ?? ""),
      expiryDays: b.expiryDays ? Number(b.expiryDays) : undefined,
    }, originOf(req));
    return ok(card, 201);
  } catch (e) { return fail(e); }
}
