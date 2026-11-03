import type { Db } from "./db";
import { DEFAULT_EXPIRY_DAYS } from "./config";
import { decrypt, encrypt, id, newLinkToken } from "./crypto";
import { bankForClub, clubSummary, logEvent, type CardRow } from "./ledger";
import { fmt } from "./money";
import { BankLoginError, bankProvider, type LinkMetadata } from "./providers/bank";
import { cardIssuer } from "./providers/issuer";

export class UserError extends Error {
  constructor(message: string, public status = 400) { super(message); }
}

export async function connectBank(db: Db, clubId: string, publicToken: string | null, metadata: LinkMetadata) {
  const acct = await bankProvider(db).exchange(publicToken, metadata);
  await db.query(
    `INSERT INTO bank_accounts (id, club_id, plaid_access_token, plaid_account_id, institution_name,
       account_name, mask, available_cents, balance_refreshed_at, status)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now(), 'connected')
     ON CONFLICT (club_id) DO UPDATE SET plaid_access_token = $3, plaid_account_id = $4,
       institution_name = $5, account_name = $6, mask = $7, available_cents = $8,
       balance_refreshed_at = now(), status = 'connected'`,
    [id("bank"), clubId, encrypt(acct.accessToken), acct.accountId, acct.institutionName,
     acct.accountName, acct.mask, acct.availableCents],
  );
  await logEvent(db, { clubId, type: "bank_connected", actor: "treasurer", data: { bank: acct.institutionName } });
}

/** Pull a fresh balance from the bank (slow in live mode). Marks the connection broken on login errors. */
export async function refreshBalance(db: Db, clubId: string) {
  const bank = await bankForClub(db, clubId);
  if (!bank) return;
  try {
    const cents = await bankProvider(db).getAvailableCents(decrypt(bank.plaid_access_token), bank.plaid_account_id);
    await db.query(
      `UPDATE bank_accounts SET available_cents = $2, balance_refreshed_at = now(), status = 'connected' WHERE club_id = $1`,
      [clubId, cents],
    );
  } catch (e) {
    if (e instanceof BankLoginError) {
      await db.query(`UPDATE bank_accounts SET status = 'broken' WHERE club_id = $1`, [clubId]);
      await logEvent(db, { clubId, type: "bank_connection_broken", actor: "system" });
      return;
    }
    throw e;
  }
}

export type NewCardInput = {
  clubId: string;
  limitCents: number;
  purpose: string;
  recipientName: string;
  recipientContact: string;
  expiryDays?: number;
};

export async function createCard(db: Db, input: NewCardInput, origin: string) {
  const purpose = input.purpose.trim();
  const recipientName = input.recipientName.trim();
  const recipientContact = input.recipientContact.trim();
  if (!purpose || !recipientName || !recipientContact) throw new UserError("Fill in every field");
  const days = input.expiryDays ?? DEFAULT_EXPIRY_DAYS;
  if (![1, 3, 7, 14].includes(days)) throw new UserError("Pick a listed expiry");

  // FR-04: fresh balance before every new card. Done outside the transaction because it can take seconds.
  await refreshBalance(db, input.clubId);
  const issuer = cardIssuer(db);
  const link = newLinkToken();
  const expiresAt = new Date(Date.now() + days * 864e5);

  return db.tx(async (t) => {
    const s = await clubSummary(t, input.clubId, true); // locks the bank row: no two cards can claim the same dollars
    if (!s.bank) throw new UserError("Connect the club's bank account first");
    if (s.bank.status !== "connected") throw new UserError("The bank connection needs fixing before you can make cards");
    if (input.limitCents > s.availableForNewCardsCents) {
      throw new UserError(`That's more than the club has free. Up to ${fmt(s.availableForNewCardsCents)} available.`);
    }

    const issued = await issuer.createCard({ limitCents: input.limitCents, purpose, expiresAt });
    const cardId = id("card");
    try {
      await t.query(
        `INSERT INTO cards (id, club_id, lithic_card_token, last4, purpose, limit_cents, recipient_name,
           recipient_contact, link_token_hash, status, expires_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'open', $10)`,
        [cardId, input.clubId, issued.token, issued.last4, purpose, input.limitCents,
         recipientName, recipientContact, link.hash, expiresAt],
      );
    } catch (e) {
      await issuer.closeCard(issued.token).catch(() => {}); // don't leave a live card we can't track
      throw e;
    }
    await logEvent(t, {
      clubId: input.clubId, cardId, type: "card_created", actor: "treasurer",
      data: { amount_cents: input.limitCents, purpose, recipient: recipientName, expiry_days: days },
    });
    return { cardId, link: `${origin}/c/${link.token}` };
  });
}

export async function getCard(db: Db, clubId: string, cardId: string): Promise<CardRow | null> {
  const [c] = await db.query<CardRow>(`SELECT * FROM cards WHERE id = $1 AND club_id = $2`, [cardId, clubId]);
  return c ?? null;
}

export async function cancelCard(db: Db, clubId: string, cardId: string) {
  const card = await getCard(db, clubId, cardId);
  if (!card) throw new UserError("Card not found", 404);
  if (card.status !== "open") throw new UserError("Only unused cards can be cancelled");
  await cardIssuer(db).closeCard(card.lithic_card_token);
  await db.query(`UPDATE cards SET status = 'cancelled' WHERE id = $1 AND status = 'open'`, [cardId]);
  await logEvent(db, { clubId, cardId, type: "card_cancelled", actor: "treasurer" });
}

/** The link is shown once (we keep only its hash). This replaces it; the old link stops working. */
export async function rotateLink(db: Db, clubId: string, cardId: string, origin: string) {
  const card = await getCard(db, clubId, cardId);
  if (!card) throw new UserError("Card not found", 404);
  if (card.status !== "open") throw new UserError("This card has closed");
  const link = newLinkToken();
  await db.query(`UPDATE cards SET link_token_hash = $2 WHERE id = $1`, [cardId, link.hash]);
  await logEvent(db, { clubId, cardId, type: "card_link_replaced", actor: "treasurer" });
  return `${origin}/c/${link.token}`;
}

export async function expireCards(db: Db) {
  const expired = await db.query<CardRow>(
    `UPDATE cards SET status = 'expired' WHERE status = 'open' AND expires_at <= now() RETURNING *`);
  const issuer = cardIssuer(db);
  for (const c of expired) {
    await issuer.closeCard(c.lithic_card_token).catch((e) => console.error("[expire] close failed", c.id, e));
    await logEvent(db, { clubId: c.club_id, cardId: c.id, type: "card_expired_unused", actor: "system" });
  }
  return expired.length;
}
