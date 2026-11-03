import Link from "next/link";
import { redirect } from "next/navigation";
import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { clubSummary } from "@/lib/ledger";
import { getClub } from "@/lib/club";
import { NewCardForm } from "@/components/NewCardForm";

export const dynamic = "force-dynamic";

export default async function NewCard() {
  const s = await clubSummary(await getDb(), CLUB_ID);
  if (!s.bank) redirect("/setup");
  const club = await getClub();
  return (
    <>
      <div className="page-head">
        <div>
          <Link className="crumb" href="/cards">Cards ›</Link>
          <h1>New card</h1>
        </div>
      </div>
      {s.bank.status === "broken" && (
        <p className="notice error">The bank connection needs fixing before you can make cards. <Link href="/setup">Reconnect</Link></p>
      )}
      <NewCardForm clubName={club.name} availableCents={s.availableForNewCardsCents} />
    </>
  );
}
