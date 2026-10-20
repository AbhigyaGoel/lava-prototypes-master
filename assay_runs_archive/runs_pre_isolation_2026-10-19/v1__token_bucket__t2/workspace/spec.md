# token_bucket

Token-bucket rate limiter. The bucket holds up to `CAP` tokens and is refilled with one token
every `rate` clock cycles. A request is granted only if a token is available, and each grant
consumes one token.

## Parameters
| Name | Default | Description |
|------|---------|-------------|
| CAP  | 4       | Bucket capacity in tokens (`1 <= CAP < 2**TW`) |
| TW   | 3       | Width of the token counter |
| RW   | 8       | Width of `rate` and of the internal refill timer |

## Ports
| Port      | Dir | Width | Description |
|-----------|-----|-------|-------------|
| clk       | in  | 1     | Rising-edge clock |
| rst_n     | in  | 1     | Asynchronous active-low reset |
| rate      | in  | RW    | Refill period in cycles; 0 disables refill. May change in any cycle. |
| req       | in  | 1     | Request for one token this cycle |
| clr_stats | in  | 1     | Synchronous clear of `deny_cnt` |
| grant     | out | 1     | Request granted this cycle (combinational) |
| tokens    | out | TW    | Tokens currently in the bucket (registered) |
| empty     | out | 1     | `tokens == 0` |
| full      | out | 1     | `tokens == CAP` |
| refill    | out | 1     | A refill occurs this cycle (combinational, see rule 3) |
| deny_cnt  | out | 8     | Number of denied requests, saturating at 255 (registered) |

## Behavior
All updates happen at the rising edge of `clk` and are computed from the values present during the
cycle before that edge.

1. **Reset.** While `rst_n` is low: `tokens = CAP` (bucket starts full), the internal refill timer
   `timer = 0`, `deny_cnt = 0`.
2. **Refill timer.** An internal RW-bit counter `timer` counts elapsed cycles of the current refill
   period. Each cycle:
   - if `rate == 0`: no refill, and `timer` is forced to 0;
   - else if `timer >= rate - 1`: a refill occurs this cycle, and `timer` becomes 0;
   - else: no refill, and `timer` increments by 1.
   With a constant nonzero `rate = R`, a refill therefore occurs exactly once every `R` cycles
   (every cycle when `R = 1`). The timer keeps running whether or not the bucket is full.
3. `refill` = 1 exactly in the cycles where rule 2 says a refill occurs:
   `refill = (rate != 0) && (timer >= rate - 1)`.
4. **Changing `rate` mid-period.** `rate` is not latched; rule 2 is evaluated with the current
   `rate` every cycle. If `rate` is reduced to a value with `rate - 1 <= timer` (i.e. the new period
   has already elapsed), the refill occurs in that same cycle and a new period starts. If `rate` is
   increased, the current period simply lasts longer. While `rate = 0` the timer stays at 0, so
   after `rate` becomes nonzero (= R) the first refill occurs R cycles later.
5. **Grant.** `grant = req && (tokens != 0)`, evaluated on the *current* `tokens` value. A token
   added by a refill in this cycle cannot be used before the next cycle. A denied request is not
   queued or remembered.
6. **Token update.** Each cycle:
   `tokens_next = min(CAP, tokens - grant + refill)`
   (`grant` and `refill` counted as 0/1). In particular:
   - refill without grant: +1, but a refill arriving while the bucket is full is discarded;
   - grant without refill: -1;
   - grant and refill in the same cycle: `tokens` is **unchanged**, including when the bucket is
     full (the granted token is replaced by the refilled one; no token is lost).
   `tokens` therefore never exceeds `CAP` and never underflows.
7. **Denied-request counter.** `deny_cnt` increments by 1 in each cycle where `req && !grant`,
   saturating at 255. If `clr_stats` is 1, `deny_cnt` becomes 0 instead (clear wins over a
   same-cycle increment).
8. `empty = (tokens == 0)` and `full = (tokens == CAP)`, combinational from `tokens`.
