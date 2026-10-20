# div_seq

Sequential unsigned 8-bit / 8-bit divider (restoring algorithm, one quotient bit per clock).
Produces an 8-bit quotient and an 8-bit remainder, with a defined divide-by-zero result and an
abort control. All outputs are registered.

## Ports
| Port      | Dir | Width | Description |
|-----------|-----|-------|-------------|
| clk       | in  | 1     | Rising-edge clock |
| rst_n     | in  | 1     | Asynchronous active-low reset |
| start     | in  | 1     | Begin a division |
| abort     | in  | 1     | Cancel the division in progress |
| dividend  | in  | 8     | Unsigned dividend |
| divisor   | in  | 8     | Unsigned divisor |
| busy      | out | 1     | 1 while a division is in progress |
| done      | out | 1     | One-cycle pulse when a division completes |
| quotient  | out | 8     | Quotient of the most recent completed division |
| remainder | out | 8     | Remainder of the most recent completed division |
| div0      | out | 1     | 1 if the most recent completed division had divisor = 0 |

## Rules
All edges are rising edges of `clk`.

1. **Reset.** While `rst_n` is low: `busy = 0`, `done = 0`, `quotient = 0`, `remainder = 0`,
   `div0 = 0`.
2. **Start.** On an edge where `busy = 0` and `start = 1`, a division is accepted: `dividend` and
   `divisor` are captured, and `busy <= 1`. Call this edge E0. `abort` is ignored while `busy = 0`
   (if `start` and `abort` are both 1 while idle, the division starts).
3. **Start while busy.** `start` is ignored on every edge where `busy = 1`; the division in progress
   continues unaffected.
4. **Operand capture.** Only the values of `dividend` and `divisor` present at E0 matter. The
   `dividend`/`divisor` inputs may change arbitrarily while `busy = 1` without affecting any output
   of that division (including `div0`).
5. **Iterations.** Edges E1 through E8 (the 8 edges following E0) each perform one restoring step.
   At E8 the division completes: `busy <= 0`, `done <= 1` (high for exactly one cycle), and
   `quotient`, `remainder`, `div0` are updated (rule 6). Thus `done` is high in the cycle after E8.
   Because `busy = 0` in the `done` cycle, a `start` in that cycle (or held continuously) is accepted
   immediately.
6. **Results.** For captured operands A and B:
   - B != 0: `quotient = floor(A / B)`, `remainder = A mod B`, `div0 = 0`.
   - B == 0: `quotient = 8'hFF`, `remainder = A`, `div0 = 1`.
   `quotient`, `remainder` and `div0` change only at a completion edge and otherwise hold
   (they do not change at E0, during iterations, or on abort).
7. **Abort.** On any edge E1..E8 where `busy = 1` and `abort = 1`, the division is cancelled:
   `busy <= 0`, `done` stays 0, and `quotient`/`remainder`/`div0` keep their previous values.
   Abort has priority over completion: an abort on E8 cancels the division (no `done`, no result
   update). A new `start` can be accepted on the edge after the abort (busy is 0 then).
