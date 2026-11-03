import { redirect } from "next/navigation";
import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { bankForClub } from "@/lib/ledger";

export const dynamic = "force-dynamic";

// No sign-in in the MVP: one seeded club and treasurer. Mock mode also seeds a connected bank.
export default async function Root() {
  const bank = await bankForClub(await getDb(), CLUB_ID);
  redirect(bank ? "/home" : "/setup");
}
