import { createHash, createHmac } from "node:crypto";
import type { Db } from "../db";
import { appUrl, mode, requireEnv } from "../config";
import { decide } from "../decide";
import { id, safeEqual } from "../crypto";

export type OfficerCardView =
  | { kind: "embed"; url: string }                              // live: Lithic renders the number in an iframe
  | { kind: "mock"; pan: string; exp: string; cvv: string };    // mock: fake numbers, never real cards

export interface CardIssuer {
  createCard(input: { limitCents: number; purpose: string; expiresAt: Date }): Promise<{ token: string; last4: string }>;
  closeCard(token: string): Promise<void>;
  officerView(card: { lithic_card_token: string; last4: string; expires_at: Date }): Promise<OfficerCardView>;
  /** Demo checkout only. A real merchant does this in production. */
  simulatePurchase(input: { pan: string; amountCents: number; merchant: string }): Promise<{ txnToken: string | null }>;
}

// ---------- mock ----------
// A fake PAN derived from the card token so the mock checkout can find the card again.
export function mockPan(token: string, last4: string): string {
  const digits = BigInt("0x" + createHash("sha256").update(token).digest("hex").slice(0, 12)).toString().slice(0, 8);
  return `4000${digits.padStart(8, "0")}${last4}`;
}
function mockCvv(token: string) {
  return String(parseInt(createHash("sha256").update("cvv" + token).digest("hex").slice(0, 6), 16) % 1000).padStart(3, "0");
}

function mockIssuer(db: Db): CardIssuer {
  return {
    async createCard() {
      return { token: id("mockcard"), last4: String(1000 + Math.floor(Math.random() * 9000)) };
    },
    async closeCard() {},
    async officerView(card) {
      const d = new Date(card.expires_at);
      return {
        kind: "mock",
        pan: mockPan(card.lithic_card_token, card.last4),
        exp: `${String(d.getUTCMonth() + 1).padStart(2, "0")}/${String(d.getUTCFullYear()).slice(2)}`,
        cvv: mockCvv(card.lithic_card_token),
      };
    },
    async simulatePurchase({ pan, amountCents, merchant }) {
      const clean = pan.replace(/\D/g, "");
      const candidates = await db.query<{ lithic_card_token: string; last4: string }>(
        `SELECT lithic_card_token, last4 FROM cards WHERE last4 = $1`, [clean.slice(-4)]);
      const match = candidates.find((c) => mockPan(c.lithic_card_token, c.last4) === clean);
      const txnToken = id("mocktxn");
      // Stand-in for the card network: in live mode Lithic calls /api/lithic/asa, which calls decide().
      await decide(db, { txnToken, cardToken: match?.lithic_card_token ?? "unknown", amountCents, merchant });
      return { txnToken };
    },
  };
}

// ---------- live (Lithic sandbox) ----------
async function lithic() {
  const { default: Lithic } = await import("lithic");
  return new Lithic({
    apiKey: requireEnv("LITHIC_API_KEY"),
    environment: (process.env.LITHIC_ENV ?? "sandbox") as "sandbox" | "production",
    webhookSecret: process.env.LITHIC_WEBHOOK_SECRET,
  });
}

const liveIssuer: CardIssuer = {
  async createCard({ limitCents, purpose, expiresAt }) {
    const l = await lithic();
    const card = await l.cards.create({
      type: "SINGLE_USE",               // Lithic closes it after the first approved purchase
      spend_limit: limitCents,          // second lock: Lithic enforces the limit even if our engine had a bug
      spend_limit_duration: "TRANSACTION",
      memo: purpose.slice(0, 64),
      exp_month: String(expiresAt.getUTCMonth() + 1).padStart(2, "0"),
      exp_year: String(expiresAt.getUTCFullYear()),
    });
    return { token: card.token, last4: card.last_four };
  },
  async closeCard(token) {
    const l = await lithic();
    await l.cards.update(token, { state: "CLOSED" });
  },
  async officerView(card) {
    const l = await lithic();
    // Signed URL; the officer's browser fetches the PAN straight from Lithic. Our server never sees it.
    // (Lithic's newer lithic-embed SDK sessions can replace this; the signed iframe URL is still supported.)
    const url = l.cards.getEmbedURL({
      token: card.lithic_card_token,
      expiration: new Date(Date.now() + 10 * 60_000).toISOString(),
      target_origin: appUrl(),
      css: `${appUrl()}/lithic-embed.css`,
    });
    return { kind: "embed", url };
  },
  async simulatePurchase({ pan, amountCents, merchant }) {
    const l = await lithic();
    // Lithic forwards this to our ASA endpoint, which runs decide() and stores the result.
    const r = await l.transactions.simulateAuthorization({
      pan: pan.replace(/\D/g, ""), amount: amountCents, descriptor: merchant.slice(0, 25).toUpperCase(),
      merchant_acceptor_city: "LOS ANGELES", merchant_acceptor_state: "CA", merchant_acceptor_country: "USA",
    });
    return { txnToken: r.token ?? null };
  },
};

export function cardIssuer(db: Db): CardIssuer {
  return mode() === "live" ? liveIssuer : mockIssuer(db);
}

/**
 * ASA request signature. Lithic signs the raw body with the ASA HMAC secret
 * (GET /v1/auth_stream/secret). Week-1 check: confirm the header name and
 * encoding against docs.lithic.com before relying on it.
 */
export function verifyAsaSignature(rawBody: string, header: string | null): boolean {
  const secret = process.env.LITHIC_ASA_SECRET;
  if (!secret || !header) return false;
  const expected = createHmac("sha256", secret).update(rawBody).digest("base64");
  return safeEqual(expected, header.trim());
}

/** Lithic transaction-event webhooks (svix-style signatures) via the SDK. */
export async function unwrapLithicEvent(rawBody: string, headers: Headers): Promise<any> {
  const l = await lithic();
  return l.webhooks.unwrap(rawBody, Object.fromEntries(headers.entries()));
}
