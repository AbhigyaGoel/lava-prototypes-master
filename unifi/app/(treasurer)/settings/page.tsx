import Link from "next/link";
import { getDb } from "@/lib/db";
import { CLUB_ID } from "@/lib/seed";
import { clubSummary } from "@/lib/ledger";
import { mode } from "@/lib/config";
import { fmt } from "@/lib/money";
import { ago } from "@/lib/format";
import { SandboxTools } from "@/components/SandboxTools";

export const dynamic = "force-dynamic";

export default async function Settings() {
  const db = await getDb();
  const s = await clubSummary(db, CLUB_ID);
  const [club] = await db.query<{ name: string; ein: string | null; treasurer: string }>(
    `SELECT name, ein, treasurer FROM clubs WHERE id = $1`, [CLUB_ID]);
  const bank = s.bank;

  return (
    <>
      <div className="page-head">
        <h1>Settings</h1>
        <Link className="btn secondary" href="/setup">Edit club and bank</Link>
      </div>

      <dl className="facts">
        <div><dt>Club</dt><dd>{club.name}</dd></div>
        <div><dt>EIN</dt><dd>{club.ein ?? "Not added"}</dd></div>
        <div><dt>Treasurer</dt><dd>{club.treasurer}</dd></div>
        <div><dt>Bank</dt><dd>{bank ? `${bank.institution_name} ••${bank.mask}` : "Not connected"}</dd></div>
        <div><dt>Available balance</dt><dd>{bank ? fmt(bank.available_cents) : "—"}</dd></div>
        <div>
          <dt>Connection</dt>
          <dd>{!bank ? "—" : bank.status === "broken" ? "Needs reconnecting" : `Connected · checked ${ago(bank.balance_refreshed_at)}`}</dd>
        </div>
      </dl>

      <SandboxTools mock={mode() === "mock"} />
    </>
  );
}
