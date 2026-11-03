import { createCipheriv, createDecipheriv, createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { mode } from "./config";

function key(): Buffer {
  const k = process.env.ENCRYPTION_KEY;
  if (k) return Buffer.from(k, "base64");
  if (mode() === "live") throw new Error("Set ENCRYPTION_KEY (32 random bytes, base64) in live mode");
  return createHash("sha256").update("unifi-mock-mode-only").digest(); // mock tokens are fake anyway
}

/** AES-256-GCM for the Plaid access token at rest. */
export function encrypt(plain: string): string {
  const iv = randomBytes(12);
  const c = createCipheriv("aes-256-gcm", key(), iv);
  const body = Buffer.concat([c.update(plain, "utf8"), c.final()]);
  return [iv, c.getAuthTag(), body].map((b) => b.toString("base64url")).join(".");
}

export function decrypt(blob: string): string {
  const [iv, tag, body] = blob.split(".").map((s) => Buffer.from(s, "base64url"));
  const d = createDecipheriv("aes-256-gcm", key(), iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(body), d.final()]).toString("utf8");
}

/** Officer link token: 32 random bytes. Only its hash is stored. */
export function newLinkToken(): { token: string; hash: string } {
  const token = randomBytes(32).toString("base64url");
  return { token, hash: hashToken(token) };
}

export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export function safeEqual(a: string, b: string): boolean {
  const x = Buffer.from(a), y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

export function id(prefix: string): string {
  return `${prefix}_${randomBytes(9).toString("base64url")}`;
}
