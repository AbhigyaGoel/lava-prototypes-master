import Link from "next/link";
import { getClub } from "@/lib/club";
import { mode } from "@/lib/config";
import { Nav } from "@/components/Nav";

export const dynamic = "force-dynamic";

export default async function TreasurerLayout({ children }: { children: React.ReactNode }) {
  const club = await getClub();
  return (
    <>
      {mode() === "mock" && <div className="sandbox-band">Mock mode: fake bank and fake cards. Nothing here moves money.</div>}
      <div className="shell">
        <aside className="side">
          <Link href="/home" className="brand"><span className="brand-mark" aria-hidden />Unifi</Link>
          <Nav />
          <div className="side-foot">
            <b>{club.name}</b>
            <span>Treasurer · {club.treasurer}</span>
          </div>
        </aside>
        <main className="main">{children}</main>
      </div>
    </>
  );
}
