# credit_tx

Sender side of a credit-based flow-controlled link. The sender starts with `N` credits; each beat
it sends consumes one credit, and the receiver returns credits (1-3 at a time) as it frees buffer
space. The sender may only send while it holds at least one credit.

## Parameters
| Name | Default | Description |
|------|---------|-------------|
| N    | 7       | Initial credit count, which is also the maximum credit count |
| CW   | 3       | Width of the `credits` counter; `N <= 2**CW - 1` (with the defaults, `N` is the largest value `credits` can hold) |

## Ports
| Port          | Dir | Width | Description |
|---------------|-----|-------|-------------|
| clk           | in  | 1     | Rising-edge clock |
| rst_n         | in  | 1     | Asynchronous active-low reset |
| in_valid      | in  | 1     | Source has a beat on `in_data` |
| in_data       | in  | 8     | Source data |
| in_ready      | out | 1     | Sender can take a beat this cycle (= `can_send`) |
| tx_valid      | out | 1     | A beat is on the link this cycle (registered) |
| tx_data       | out | 8     | Link data (registered) |
| credit_return | in  | 1     | Receiver returns credits this cycle |
| credit_count  | in  | 2     | Number of credits returned when `credit_return = 1` |
| can_send      | out | 1     | `credits != 0` (combinational from the register) |
| credits       | out | CW    | Current credit count (registered) |
| credit_err    | out | 1     | Sticky protocol-error flag (registered) |
| beats_sent    | out | 16    | Number of beats sent since reset, wrapping (registered) |

## Behavior
All updates happen at the rising edge of `clk` and use the values of the cycle before that edge.

1. **Reset.** While `rst_n` is low: `credits = N`, `credit_err = 0`, `tx_valid = 0`,
   `tx_data = 0`, `beats_sent = 0`.
2. `can_send = (credits != 0)` and `in_ready = can_send`.
3. **Send.** `send = in_valid && can_send`. When `send = 1`, at the next edge `tx_valid` becomes 1,
   `tx_data` takes `in_data` and `beats_sent` increments by 1 (wrapping at 16 bits). When
   `send = 0`, `tx_valid` becomes 0 and `tx_data` / `beats_sent` hold.
4. **Returned credits.** In each cycle the number of returned credits is
   `R = credit_return ? credit_count : 0` (so `credit_count = 0` returns nothing). A return
   is independent of sending: credits can be returned in the same cycle as a send, and both
   must be accounted for.
5. **Credit update.** Let `S = credits - send + R`, computed with full precision (no wrap-around;
   `S` ranges from 0 up to `N + 3`). Then:
   - if `S <= N`: `credits_next = S`;
   - if `S > N` (the receiver returned more credits than were outstanding, a protocol error):
     `credits_next = N` (saturate) and `credit_err` becomes 1.
   The counter never underflows (a send requires `credits >= 1`) and never exceeds `N`.
6. **credit_err** is sticky: once set it stays 1 until reset, regardless of later traffic or
   valid credit returns.
7. Example (N = 7): `credits = 5`, `send = 1`, `credit_return = 1`, `credit_count = 2` ->
   `credits_next = 6`, no error. `credits = 6`, `send = 0`, `credit_count = 3` returned ->
   `S = 9 > 7`, so `credits_next = 7` and `credit_err = 1`.
