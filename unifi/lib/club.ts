import { getDb } from "./db";
import { CLUB_ID } from "./seed";

export async function getClub() {
  const db = await getDb();
  const [c] = await db.query<{ id: string; name: string; treasurer: string }>(`SELECT * FROM clubs WHERE id = $1`, [CLUB_ID]);
  return c;
}
