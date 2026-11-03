import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { cancelCard } from "@/lib/cards";
import { fail, ok } from "@/lib/http";

export async function POST(_req: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    await cancelCard(await getDb(), CLUB_ID, (await params).id);
    return ok({ cancelled: true });
  } catch (e) { return fail(e); }
}
