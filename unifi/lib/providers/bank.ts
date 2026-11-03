import type { Db } from "../db";
import { mode, requireEnv } from "../config";
import { id } from "../crypto";

export class BankLoginError extends Error {}

export type LinkedAccount = {
  accessToken: string;
  accountId: string;
  institutionName: string;
  accountName: string;
  mask: string;
  availableCents: number;
};

export type LinkMetadata = {
  institution?: { name?: string } | null;
  accounts?: { id: string; name?: string; mask?: string | null }[];
};

export interface BankProvider {
  /** Plaid Link token for the browser; null in mock mode (no Link UI). */
  createLinkToken(clubId: string): Promise<string | null>;
  exchange(publicToken: string | null, metadata: LinkMetadata): Promise<LinkedAccount>;
  /** Real-time balance. Slow in live mode (seconds), so never call it inside a purchase decision. */
  getAvailableCents(accessToken: string, accountId: string): Promise<number>;
}

// ---------- mock ----------
const MOCK_START_CENTS = Number(process.env.MOCK_BALANCE_CENTS ?? 124000);

function mockBank(db: Db): BankProvider {
  return {
    async createLinkToken() {
      return null;
    },
    async exchange() {
      const accessToken = id("mock_access");
      await db.query(`INSERT INTO mock_bank (access_token, available_cents) VALUES ($1, $2)`, [accessToken, MOCK_START_CENTS]);
      return {
        accessToken,
        accountId: "mock_account",
        institutionName: "USC Credit Union (mock)",
        accountName: "Cardinal Checking",
        mask: "4821",
        availableCents: MOCK_START_CENTS,
      };
    },
    async getAvailableCents(accessToken) {
      const [r] = await db.query<{ available_cents: number }>(
        `SELECT available_cents FROM mock_bank WHERE access_token = $1`, [accessToken]);
      if (!r) throw new BankLoginError("mock bank item not found");
      return r.available_cents;
    },
  };
}

// ---------- live (Plaid sandbox) ----------
async function plaidClient() {
  const { Configuration, PlaidApi, PlaidEnvironments } = await import("plaid");
  const env = (process.env.PLAID_ENV ?? "sandbox") as keyof typeof PlaidEnvironments;
  return new PlaidApi(new Configuration({
    basePath: PlaidEnvironments[env],
    baseOptions: { headers: {
      "PLAID-CLIENT-ID": requireEnv("PLAID_CLIENT_ID"),
      "PLAID-SECRET": requireEnv("PLAID_SECRET"),
    } },
  }));
}

function isLoginError(e: any) {
  const code = e?.response?.data?.error_code;
  return code === "ITEM_LOGIN_REQUIRED" || code === "ITEM_LOCKED" || code === "INVALID_CREDENTIALS";
}

const liveBank: BankProvider = {
  async createLinkToken(clubId) {
    const { Products, CountryCode } = await import("plaid");
    const plaid = await plaidClient();
    const r = await plaid.linkTokenCreate({
      user: { client_user_id: clubId },
      client_name: "Unifi",
      products: [Products.Auth],
      country_codes: [CountryCode.Us],
      language: "en",
      account_filters: { depository: { account_subtypes: ["checking" as any] } },
    });
    return r.data.link_token;
  },
  async exchange(publicToken, metadata) {
    if (!publicToken) throw new Error("missing public token");
    const plaid = await plaidClient();
    const { data } = await plaid.itemPublicTokenExchange({ public_token: publicToken });
    const picked = metadata.accounts?.[0];
    if (!picked) throw new Error("no account selected in Link");
    const availableCents = await liveBank.getAvailableCents(data.access_token, picked.id);
    return {
      accessToken: data.access_token,
      accountId: picked.id,
      institutionName: metadata.institution?.name ?? "Bank",
      accountName: picked.name ?? "Checking",
      mask: picked.mask ?? "????",
      availableCents,
    };
  },
  async getAvailableCents(accessToken, accountId) {
    const plaid = await plaidClient();
    try {
      const { data } = await plaid.accountsBalanceGet({ access_token: accessToken, options: { account_ids: [accountId] } });
      const b = data.accounts[0]?.balances;
      const dollars = b?.available ?? b?.current; // available is missing for ~9% of accounts
      if (dollars == null) throw new Error("no balance returned");
      return Math.round(dollars * 100);
    } catch (e) {
      if (isLoginError(e)) throw new BankLoginError("bank login needs repair");
      throw e;
    }
  },
};

export function bankProvider(db: Db): BankProvider {
  return mode() === "live" ? liveBank : mockBank(db);
}
