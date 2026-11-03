import { NextResponse } from "next/server";
import { UserError } from "./cards";

export function ok(data: unknown, status = 200) {
  return NextResponse.json(data, { status });
}

export function fail(e: unknown) {
  if (e instanceof UserError) return NextResponse.json({ error: e.message }, { status: e.status });
  console.error(e);
  return NextResponse.json({ error: "Something went wrong. Try again." }, { status: 500 });
}

export function originOf(req: Request): string {
  return process.env.APP_URL?.replace(/\/$/, "") ?? new URL(req.url).origin;
}

/** Vercel Cron sends `Authorization: Bearer $CRON_SECRET`. Open when no secret is set (local dev). */
export function cronAllowed(req: Request): boolean {
  const s = process.env.CRON_SECRET;
  return !s || req.headers.get("authorization") === `Bearer ${s}`;
}
