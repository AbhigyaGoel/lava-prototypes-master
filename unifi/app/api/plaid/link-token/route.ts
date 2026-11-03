import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { bankProvider } from "@/lib/providers/bank";
import { fail, ok } from "@/lib/http";

export async function POST() {
  try {
    const db = await getDb();
    return ok({ linkToken: await bankProvider(db).createLinkToken(CLUB_ID) });
  } catch (e) { return fail(e); }
}
