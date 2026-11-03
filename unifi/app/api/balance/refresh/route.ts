import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { refreshBalance } from "@/lib/cards";
import { fail, ok } from "@/lib/http";

export async function POST() {
  try {
    await refreshBalance(await getDb(), CLUB_ID);
    return ok({ refreshed: true });
  } catch (e) { return fail(e); }
}
