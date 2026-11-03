"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";

const ITEMS = [
  { href: "/home", label: "Home" },
  { href: "/cards", label: "Cards" },
  { href: "/purchases", label: "Purchases" },
  { href: "/settings", label: "Settings" },
];

export function Nav() {
  const path = usePathname();
  return (
    <nav className="nav" aria-label="Main">
      {ITEMS.map((i) => (
        <Link key={i.href} href={i.href} aria-current={path === i.href || path.startsWith(i.href + "/") ? "page" : undefined}>
          {i.label}
        </Link>
      ))}
    </nav>
  );
}
