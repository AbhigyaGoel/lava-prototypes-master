# sync_fifo

Single-clock FIFO, depth 8, data width 8, with full/empty flags, an occupancy count, and
overflow/underflow protection.

## Ports
| Port  | Dir | Width | Description |
|-------|-----|-------|-------------|
| clk   | in  | 1     | Rising-edge clock |
| rst_n | in  | 1     | Asynchronous active-low reset |
| wr_en | in  | 1     | Write request |
| din   | in  | 8     | Write data |
| rd_en | in  | 1     | Read request |
| dout  | out | 8     | Read data (registered) |
| full  | out | 1     | 1 when the FIFO holds 8 entries |
| empty | out | 1     | 1 when the FIFO holds 0 entries |
| count | out | 4     | Number of entries currently stored (0..8, registered) |

## Behavior
- While `rst_n` is low: the FIFO is emptied (`count = 0`, read/write pointers 0) and `dout = 0`.
  The storage array itself is not reset.
- `full = (count == 8)` and `empty = (count == 0)`; both are combinational from `count`.
- In each cycle the decisions are made from the state *before* the clock edge:
  - A write is **accepted** iff `wr_en && !full`. An accepted write stores `din` at the tail.
    A write while full is ignored (no overflow; stored data is not disturbed). This holds even if
    a read is accepted in the same cycle: when full, a write is rejected regardless of `rd_en`.
  - A read is **accepted** iff `rd_en && !empty`. An accepted read loads the oldest entry into
    `dout` on that clock edge and removes it. A read while empty is ignored (no underflow):
    pointers, `count` and `dout` are unchanged.
  - `dout` holds its value in every cycle without an accepted read.
- `count` update per edge: +1 if only the write is accepted, -1 if only the read is accepted,
  unchanged if both or neither are accepted.
- Simultaneous accepted read and write (possible when `0 < count < 8`) performs both: the oldest
  entry goes to `dout`, `din` is appended, and `count` stays the same.
- When empty and both `wr_en` and `rd_en` are high, only the write happens (`count` becomes 1,
  `dout` unchanged). When full and both are high, only the read happens (`count` becomes 7).
- Data is delivered strictly in first-in first-out order.
