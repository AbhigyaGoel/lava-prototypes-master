const TZ = process.env.DISPLAY_TZ ?? "America/Los_Angeles";

export function day(d: Date | string) {
  return new Date(d).toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: TZ });
}
export function when(d: Date | string) {
  return new Date(d).toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit", timeZone: TZ });
}
export function ago(d: Date | string) {
  const m = Math.round((Date.now() - new Date(d).getTime()) / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m} min ago`;
  return `${Math.round(m / 60)} h ago`;
}
