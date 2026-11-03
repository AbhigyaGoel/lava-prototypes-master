import { REASON_TEXT, type DeclineReason } from "./decide";
import type { CardRow } from "./ledger";
import { fmt } from "./money";

const TZ = process.env.DISPLAY_TZ ?? "America/Los_Angeles";

export const CARD_STATUS: Record<CardRow["status"], { label: string; tone: "outline" | "solid" | "grey" }> = {
  open: { label: "Unused", tone: "outline" },
  used: { label: "Used", tone: "solid" },
  cancelled: { label: "Cancelled", tone: "grey" },
  expired: { label: "Expired", tone: "grey" },
};

/** Treasurer-facing reason. Names the card limit when that's the cause ("Over the $120 card limit"). */
export function reasonText(reason: string | null, limitCents?: number | null): string {
  if (!reason) return "";
  if (reason === "OVER_CARD_LIMIT" && limitCents) {
    const whole = limitCents % 100 === 0 ? `$${(limitCents / 100).toLocaleString("en-US")}` : fmt(limitCents);
    return `Over the ${whole} card limit`;
  }
  return REASON_TEXT[reason as DeclineReason] ?? reason;
}

function ymd(d: Date) {
  return d.toLocaleDateString("en-CA", { timeZone: TZ });
}

/** "Today 6:02 PM" for today, otherwise "Oct 30". */
export function whenShort(d: Date | string) {
  const date = new Date(d);
  if (ymd(date) === ymd(new Date())) {
    return `Today ${date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", timeZone: TZ })}`;
  }
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: TZ });
}

export function greeting(now = new Date()) {
  const h = Number(now.toLocaleString("en-US", { hour: "numeric", hour12: false, timeZone: TZ }));
  return h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening";
}

/** First day of this month in the display time zone, as an ISO string for SQL. */
export function startOfMonthISO(now = new Date()) {
  const [y, m] = ymd(now).split("-");
  // Offset-free midnight in UTC is close enough for a "this month" tile.
  return new Date(`${y}-${m}-01T00:00:00Z`).toISOString();
}

/** Whole dollars when round ("$180"), cents otherwise. Used on card faces. */
export function dollarsShort(cents: number) {
  return cents % 100 === 0 ? `$${(cents / 100).toLocaleString("en-US")}` : fmt(cents);
}
