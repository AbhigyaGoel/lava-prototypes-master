/**
 * MODE
 *  mock  no keys needed. Fake bank, fake cards, purchases go straight to our decision engine.
 *  live  Plaid sandbox + Lithic sandbox. Still test money; "live" means real vendor APIs.
 */
export type Mode = "mock" | "live";

export function mode(): Mode {
  const m = process.env.UNIFI_MODE;
  if (m === "mock" || m === "live") return m;
  return process.env.LITHIC_API_KEY && process.env.PLAID_CLIENT_ID ? "live" : "mock";
}

export const BALANCE_MAX_AGE_MS = 15 * 60 * 1000; // PRD guardrail: never decide on a balance older than this
export const DEFAULT_EXPIRY_DAYS = 7;

export function appUrl(): string {
  return (process.env.APP_URL ?? "http://localhost:3000").replace(/\/$/, "");
}

export function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var ${name}`);
  return v;
}
