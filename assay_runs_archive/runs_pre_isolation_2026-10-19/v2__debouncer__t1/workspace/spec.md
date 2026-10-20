# debouncer

A counter-based debouncer for a single, already-synchronous input.

## Parameters
| Name | Default | Description |
|------|---------|-------------|
| N    | 4       | Number of consecutive cycles the input must differ from the output before the output changes. Legal range 2..255. |

## Ports
| Port  | Dir | Width | Description |
|-------|-----|-------|-------------|
| clk   | in  | 1     | Rising-edge clock |
| rst_n | in  | 1     | Asynchronous active-low reset |
| din   | in  | 1     | Raw input (synchronous to `clk`) |
| dout  | out | 1     | Debounced output (registered) |

## Behavior
- While `rst_n` is low, `dout` is 0 and the internal stability counter is 0.
- At each rising edge of `clk`, `din` is sampled and compared with the current `dout`:
  - If `din == dout`, the stability counter is cleared to 0 (any partial run of
    differing samples is discarded) and `dout` holds.
  - If `din != dout`, the counter advances. When this is the **N-th consecutive** edge at which
    `din != dout` was sampled, `dout` takes the value of `din` at that same edge and the counter
    is cleared to 0.
- Therefore `dout` toggles exactly at the N-th consecutive rising edge with `din != dout`
  (with N = 4: if `din` goes high just before edge 1 and stays high, `dout` becomes 1 right after
  edge 4). A disagreement that lasts fewer than N consecutive edges never changes `dout`, no
  matter how many such short glitches occur.
- The internal counter must be wide enough for N up to 255.
