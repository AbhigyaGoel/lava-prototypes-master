import { getDb } from "@/lib/db";
import { expireCards } from "@/lib/cards";
import { cronAllowed, fail, ok } from "@/lib/http";

export async function GET(req: Request) {
  if (!cronAllowed(req)) return ok({ error: "unauthorized" }, 401);
  try {
    return ok({ expired: await expireCards(await getDb()) });
  } catch (e) { return fail(e); }
}
