import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { getCard, UserError } from "@/lib/cards";
import { logEvent } from "@/lib/ledger";
import { fail, ok } from "@/lib/http";

/**
 * Sending is faked in the MVP (spec FR-12: "Copy link" button). When the treasurer copies the link
 * we record it, so Card detail can show when the link went out and the activity log stays truthful.
 */
export async function POST(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const db = await getDb();
    const card = await getCard(db, CLUB_ID, (await params).id);
    if (!card) throw new UserError("Card not found", 404);
    const [seen] = await db.query(
      `SELECT 1 FROM events WHERE card_id = $1 AND type = 'card_link_copied' AND created_at > now() - interval '1 minute' LIMIT 1`,
      [card.id]);
    if (!seen) {
      await logEvent(db, { clubId: CLUB_ID, cardId: card.id, type: "card_link_copied", actor: "treasurer",
        data: { to: card.recipient_contact } });
    }
    return ok({ ok: true });
  } catch (e) { return fail(e); }
}
