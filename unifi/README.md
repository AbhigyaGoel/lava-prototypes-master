# Unifi MVP

One feature: a treasurer makes a single-use card from the club's existing bank account, an officer pays with it, and Unifi approves the purchase only if it fits the card limit **and** the club's balance.

Built from the *Unifi MVP Build Spec*. Everything runs on test money.

## Run it (no accounts needed)

```bash
npm install
npm run dev            # http://localhost:3000
```

With no keys set, the app runs in **mock mode**: a fake bank ($1,240), fake cards, and purchases go straight to the real decision engine. The database is PGlite (Postgres in WASM) stored in `.data/`; delete that folder to start over.

### Demo script (matches the pitch)

There's no sign-in: the app is seeded with one club (NSBE at USC) and treasurer (Devin), and in mock mode the fake bank is already connected with $1,240, so the app opens on Home.

1. **Bank.** Home shows the club balance. (*Settings → Edit club and bank* shows the connected account; in live mode, connect through Plaid there first.)
2. **Make a card.** $700, "GBM food", Jordan Lee → *Create card* → *Copy link*.
3. **Officer view.** Open the link (try it on a phone width). Copy the number.
4. **Pay.** Open `/checkout` → paste the number → $612.40 at Raising Cane's → *Pay* → **Purchase approved**.
5. **Limits hold.** Pay again with the same card → declined, *Card already used or closed*. Card detail and Purchases show both attempts and why.

Bonus for Q&A: in *Settings → Demo tools*, set the fake bank balance to $300, make a $500 card, try $400 → *Club balance too low*.

## Screens (Figma: Club Cards MVP Wireframes, web)

| Frame | Route |
| --- | --- |
| 1 · Sign in | removed: no sign-in in the MVP (seeded account) |
| 2 · Connect bank | `/setup` |
| 3 · Home | `/home` |
| 4 · New card | `/cards/new` |
| 5 · Card detail | `/cards/:id` |
| 6 · Officer card page | `/c/:linkToken` (public) |
| 7 · Purchases | `/purchases` (search, status, officer, date range, Export CSV) |
| not in Figma | `/cards` (all cards), `/settings` (club, bank, demo tools), `/checkout` (spec's mock checkout) |

Where the spec overrides the wireframes: "Create and send" is *Create card* plus a *Copy link* step (FR-12 faked), and *Resend link* makes a fresh link to copy, since only the link's hash is stored. Copying a link is logged, so Card detail's *Sent* and *Activity* stay truthful.

## Tests

```bash
npm test                          # T4–T11: decision engine against real Postgres (PGlite)
scripts/demo-check.sh             # whole flow over HTTP; needs `npm run dev` running in mock mode with a fresh .data/
```

## How it's built

| Piece | Where |
| --- | --- |
| Decision engine (the core) | `lib/decide.ts` |
| Balances, holds, summaries | `lib/ledger.ts` |
| Card create / cancel / link / expiry | `lib/cards.ts` |
| Plaid (mock + live) | `lib/providers/bank.ts` |
| Lithic (mock + live) | `lib/providers/issuer.ts` |
| Lithic ASA webhook | `app/api/lithic/asa/route.ts` |
| Lithic transaction events | `app/api/lithic/events/route.ts` |
| Schema | `lib/schema.ts` |

Rules the engine follows:
- Reads only our database during a purchase. Plaid's live balance takes ~3–11 s, so a cron refreshes it every 10 min and the engine **declines if the cached balance is over 15 minutes old**.
- Spendable = cached bank balance − approved purchases (held or settled). Settled purchases keep counting because the club debit is simulated and never reaches the bank.
- Locks the club's bank row per purchase, so two cards can't spend the same dollars.
- Same Lithic transaction token → same answer, one hold.
- Any error or a reply slower than 800 ms → decline.
- Lithic also enforces the card limit itself (`spend_limit`, `SINGLE_USE`), a second lock in case our code has a bug.
- Card numbers: Lithic's hosted iframe shows them in live mode; our server never stores or sees them. The one exception is `/api/dev/simulate`, the test checkout, which is sandbox-only.

## Going live on the sandboxes

1. Copy `.env.example` to `.env.local`. Fill in Plaid and Lithic sandbox keys, `ENCRYPTION_KEY`, `CRON_SECRET`, and `DATABASE_URL` (Supabase).
2. Deploy to Vercel (Lithic must reach your ASA URL over HTTPS; for local work use a tunnel such as ngrok).
3. In Lithic: enroll `https://<app>/api/lithic/asa` for Auth Stream Access and put the ASA secret in `LITHIC_ASA_SECRET`. Add a webhook to `https://<app>/api/lithic/events` for `card_transaction.updated`.
4. Connect with Plaid using sandbox login `user_good` / `pass_good`.

## Week-1 checks before trusting live mode

Not run here: this build hasn't talked to the real Plaid or Lithic APIs yet (no keys in this environment). Typecheck passes against both SDKs, but confirm:

- [ ] **ASA signature:** header name (`X-Lithic-HMAC` assumed) and encoding in `verifyAsaSignature`.
- [ ] **ASA response:** that `{ token, result }` with the decline codes in `RESULT_FOR` is accepted.
- [ ] **ASA timeout:** Lithic's limit and what it does when we don't answer; set it to decline.
- [ ] **Single-use + spend limit** on card create are accepted together with the custom expiry.
- [ ] **Embed:** the signed iframe URL renders; Lithic's newer `lithic-embed` SDK is the replacement if it doesn't.
- [ ] **Race test on real Postgres:** PGlite runs one transaction at a time, so T8 passing there doesn't prove the row lock. Rerun `npm test` with the race test pointed at Supabase.

## Known gaps (on purpose, per the spec)

- **No sign-in.** One seeded club and treasurer (`lib/seed.ts`); mock mode also seeds a connected fake bank. Anyone with the URL can use the treasurer pages. Fine for a sandbox demo, not beyond it; add Supabase Auth magic links next.
- **No email or text sending.** The treasurer copies the link.
- **Unsupported-bank waitlist** stores the email as an event; nothing reads it yet.
- **Cron frequency.** Vercel's Hobby plan runs crons at most once a day, which would leave balances stale and decline everything. Use Vercel Pro, Supabase `pg_cron`, or a GitHub Actions schedule hitting `/api/cron/refresh-balance` every 10 min. Making a card and the *Refresh balance* button also refresh it.
- **Restaurant tips** and partial refunds aren't handled.
