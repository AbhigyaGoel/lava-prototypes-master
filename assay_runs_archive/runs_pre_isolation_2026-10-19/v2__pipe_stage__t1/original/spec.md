# pipe_stage

A valid/ready pipeline stage implemented as a **2-entry skid buffer** with a *registered*
`in_ready`. Data passes through unchanged (8 bits). The stage must never drop, duplicate or
reorder data, under any pattern of `in_valid` and `out_ready`.

## Ports
| Port      | Dir | Width | Description |
|-----------|-----|-------|-------------|
| clk       | in  | 1     | Rising-edge clock |
| rst_n     | in  | 1     | Asynchronous active-low reset |
| in_valid  | in  | 1     | Upstream has a word on `in_data` |
| in_ready  | out | 1     | Stage can accept a word this cycle |
| in_data   | in  | 8     | Upstream data |
| out_valid | out | 1     | Stage presents a word on `out_data` (registered) |
| out_ready | in  | 1     | Downstream accepts the word this cycle |
| out_data  | out | 8     | Downstream data (registered) |

## Handshake
- A word is **accepted** at a rising edge when `in_valid && in_ready` is 1 in the cycle before it.
- A word is **delivered** at a rising edge when `out_valid && out_ready` is 1 in the cycle before it.
- Words are delivered in exactly the order they were accepted, each exactly once, with
  `out_data` equal to the accepted `in_data`.

## Structure and timing
- The stage holds up to two words: the **output register** (`out_valid`/`out_data`) and one
  **skid register** behind it. Let `occ` (0, 1 or 2) be the number of words held.
- `out_valid` is 1 iff `occ >= 1`; `out_data` is then the oldest held word.
- `in_ready` is 1 iff the skid register is empty, i.e. iff `occ <= 1`. It is a function of the
  stage's registered state only and must **not** depend combinationally on `out_ready` or
  `in_valid`.
- Each cycle `occ` changes by (+1 if a word is accepted) and (-1 if a word is delivered).
  An accepted word goes directly into the output register when the output register is empty or is
  being delivered in the same cycle (and the skid register is empty); otherwise it goes into the
  skid register. When the output register is delivered while the skid register is full, the skid
  word moves into the output register and the skid register becomes empty.
- With `out_ready` held high, the stage sustains one word per cycle with one cycle of latency.
- While `rst_n` is low the stage is empty (`out_valid = 0`, `in_ready = 1`).
