import type { Db } from "./db";
import { mode } from "./config";

export const CLUB_ID = "club_nsbe_usc";

/** MVP has no sign-in: one seeded club and treasurer (spec: FR-01/02 faked). */
export async function seed(db: Db) {
  await db.query(
    `INSERT INTO clubs (id, name, treasurer) VALUES ($1, $2, $3) ON CONFLICT (id) DO NOTHING`,
    [CLUB_ID, process.env.CLUB_NAME ?? "NSBE at USC", process.env.TREASURER_NAME ?? "Devin"],
  );
}

/**
 * App start-up only (not tests): in mock mode, connect the fake bank ($1,240) so the app opens
 * ready to make cards. Live mode still connects through Plaid on /setup, since that needs a real login.
 */
export async function seedDemo(db: Db) {
  if (mode() !== "mock") return;
  const [bank] = await db.query(`SELECT 1 FROM bank_accounts WHERE club_id = $1`, [CLUB_ID]);
  if (bank) return;
  const { connectBank } = await import("./cards");
  await connectBank(db, CLUB_ID, null, {});
}
