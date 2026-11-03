// Unifi MVP schema. Kept as a string so it ships with the server bundle.
export const SCHEMA = `
-- Unifi MVP schema. All money is integer cents.
-- No table holds a full card number or a bank account number.

CREATE TABLE IF NOT EXISTS clubs (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  ein         TEXT,
  treasurer   TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bank_accounts (
  id                    TEXT PRIMARY KEY,
  club_id               TEXT NOT NULL UNIQUE REFERENCES clubs(id),
  plaid_access_token    TEXT NOT NULL,          -- encrypted at rest (lib/crypto.ts)
  plaid_account_id      TEXT NOT NULL,
  institution_name      TEXT NOT NULL,
  account_name          TEXT NOT NULL,
  mask                  TEXT NOT NULL,
  available_cents       INTEGER NOT NULL,
  balance_refreshed_at  TIMESTAMPTZ NOT NULL,
  status                TEXT NOT NULL DEFAULT 'connected'   -- connected | broken
);

CREATE TABLE IF NOT EXISTS cards (
  id                 TEXT PRIMARY KEY,
  club_id            TEXT NOT NULL REFERENCES clubs(id),
  lithic_card_token  TEXT NOT NULL UNIQUE,
  last4              TEXT NOT NULL,
  purpose            TEXT NOT NULL,
  limit_cents        INTEGER NOT NULL CHECK (limit_cents > 0),
  recipient_name     TEXT NOT NULL,
  recipient_contact  TEXT NOT NULL,
  link_token_hash    TEXT NOT NULL UNIQUE,     -- sha256 of the officer link token
  status             TEXT NOT NULL DEFAULT 'open',  -- open | used | cancelled | expired
  expires_at         TIMESTAMPTZ NOT NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One row per purchase attempt. status:
--   held     approved, waiting for clearing
--   settled  cleared; in the sandbox the club debit is simulated, so it still counts as spent
--   released voided/reversed; no longer counts
--   declined never counted
CREATE TABLE IF NOT EXISTS authorizations (
  id                TEXT PRIMARY KEY,
  card_id           TEXT REFERENCES cards(id),
  club_id           TEXT REFERENCES clubs(id),
  lithic_txn_token  TEXT NOT NULL UNIQUE,
  amount_cents      INTEGER NOT NULL,
  merchant          TEXT NOT NULL,
  decision          TEXT NOT NULL,             -- APPROVED | DECLINED
  decline_reason    TEXT,
  status            TEXT NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS authorizations_club_status ON authorizations (club_id, status);
CREATE INDEX IF NOT EXISTS authorizations_card ON authorizations (card_id, created_at DESC);

CREATE TABLE IF NOT EXISTS events (
  id          BIGSERIAL PRIMARY KEY,
  club_id     TEXT,
  card_id     TEXT,
  type        TEXT NOT NULL,
  actor       TEXT NOT NULL,
  data        JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS events_card ON events (card_id, created_at);

-- Mock mode only: the fake bank's balance, so the demo can lower it on purpose (T7).
CREATE TABLE IF NOT EXISTS mock_bank (
  access_token     TEXT PRIMARY KEY,
  available_cents  INTEGER NOT NULL
);
`;
