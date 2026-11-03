import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { rotateLink } from "@/lib/cards";
import { fail, ok, originOf } from "@/lib/http";

export async function POST(req: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    return ok({ link: await rotateLink(await getDb(), CLUB_ID, (await params).id, originOf(req)) });
  } catch (e) { return fail(e); }
}
