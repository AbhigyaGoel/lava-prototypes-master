import type { Metadata } from "next";
import Link from "next/link";
import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { clubSummary } from "@/lib/ledger";
import { mode } from "@/lib/config";
import { ClubSetup } from "@/components/ClubSetup";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Set up · Unifi" };

export default async function Setup() {
  const db = await getDb();
  const s = await clubSummary(db, CLUB_ID);
  const [club] = await db.query<{ name: string; ein: string | null }>(`SELECT name, ein FROM clubs WHERE id = $1`, [CLUB_ID]);
  const [{ n: cardCount }] = await db.query<{ n: number }>(`SELECT COUNT(*)::int AS n FROM cards WHERE club_id = $1`, [CLUB_ID]);
  const bank = s.bank && {
    institution: s.bank.institution_name,
    account: s.bank.account_name,
    mask: s.bank.mask,
    availableCents: s.bank.available_cents,
    broken: s.bank.status === "broken",
  };

  return (
    <>
      {mode() === "mock" && <div className="sandbox-band">Mock mode: the bank is fake and connects without a Plaid window.</div>}
      <div className="setup">
        <aside className="setup-rail">
          <Link href={bank ? "/home" : "/setup"} className="brand"><span className="brand-mark" aria-hidden />Unifi</Link>
          <ol className="steps" aria-label="Setup steps">
            <li aria-current="step"><span className="dot">1</span>Club and bank account</li>
            <li><span className="dot">2</span>Make your first card</li>
          </ol>
        </aside>
        <main className="setup-main">
          <p className="step-label">Step 1 of 2</p>
          <h1>Connect your club's bank account</h1>
          <p className="muted">Cards are paid from this account only when they're used. No money moves now.</p>
          <ClubSetup clubName={club.name} ein={club.ein ?? ""} bank={bank} next={cardCount ? "/home" : "/cards/new"} />
        </main>
      </div>
    </>
  );
}
