# mult_seq

Sequential signed 8 x 8 -> 16-bit multiplier (radix-2 shift-add, one multiplier bit per cycle)
with a `start` / `busy` / `done` handshake.

## Ports
| Port    | Dir | Width | Description |
|---------|-----|-------|-------------|
| clk     | in  | 1     | Rising-edge clock |
| rst_n   | in  | 1     | Asynchronous active-low reset |
| start   | in  | 1     | Request a new multiplication of `a` and `b` |
| a       | in  | 8     | Multiplicand, signed two's complement (-128..127) |
| b       | in  | 8     | Multiplier, signed two's complement (-128..127) |
| busy    | out | 1     | A multiplication is in progress (registered) |
| done    | out | 1     | Completion pulse (registered) |
| product | out | 16    | Result `a * b`, signed two's complement (registered) |

## Rules
1. **Accepting an operation.** A `start` is *accepted* at a rising edge of `clk` iff `start = 1`
   and `busy = 0` in the cycle before that edge. `a` and `b` are sampled at that edge; they may
   change freely afterwards.
2. **start while busy is ignored.** If `start = 1` while `busy = 1`, it has no effect at all: the
   running operation continues undisturbed and no new operation is queued.
3. **Latency.** If an operation is accepted at edge E0, then `busy = 1` after edges E0 .. E7
   (exactly 8 cycles) and the operation completes at edge E8: after E8, `busy = 0`, `done = 1` and
   `product` holds the result.
4. **done** is a single-cycle pulse: it is 1 only in the one cycle following the completing edge
   E8, and 0 in every other cycle (including while idle and while busy).
5. **Back-to-back.** In the cycle where `done = 1`, `busy` is already 0, so a `start` in that
   cycle is accepted (and `done` returns to 0 after that edge as per rule 4).
6. **product** changes only at a completing edge. It holds the most recent result from that edge
   until the next completing edge: it does not change when an operation is accepted or while
   `busy = 1`.
7. **Result.** `product` equals the exact mathematical product of the signed values of `a` and `b`,
   as a 16-bit two's-complement number. This holds for all 65536 operand pairs; the extreme cases
   are representable:

   | a    | b    | product (decimal) | product (hex) |
   |------|------|-------------------|---------------|
   | -128 | -128 | 16384             | 16'h4000      |
   | -128 | 127  | -16256            | 16'hC080      |
   | 127  | -128 | -16256            | 16'hC080      |
   | 127  | 127  | 16129             | 16'h3F01      |
   | -1   | -1   | 1                 | 16'h0001      |
   | -128 | 0    | 0                 | 16'h0000      |

8. While `rst_n` is low: `busy = 0`, `done = 0`, `product = 0`, and any operation in progress is
   abandoned.
