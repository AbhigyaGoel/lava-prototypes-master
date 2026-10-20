# clock_divider

A programmable divide-by-N divider producing a 50%-duty divided clock (for even N) and a
one-cycle enable tick per divided period.

## Ports
| Port    | Dir | Width | Description |
|---------|-----|-------|-------------|
| clk     | in  | 1     | Rising-edge clock |
| rst_n   | in  | 1     | Asynchronous active-low reset |
| div     | in  | 8     | Divisor N (may change at any time) |
| clk_out | out | 1     | Divided clock (combinational decode of the counter) |
| tick    | out | 1     | Enable pulse, high in the last cycle of each divided period (combinational) |

## Behavior
- Effective divisor: `N = (div < 2) ? 2 : div`. In other words, **both `div = 0` and `div = 1`
  behave exactly like `div = 2`**. `div` is used combinationally (no latching).
- An internal 8-bit counter `cnt` resets to 0 while `rst_n` is low.
- `tick = (cnt >= N - 1)`.
- On each rising edge of `clk`: if `tick` is high, `cnt <= 0`; otherwise `cnt <= cnt + 1`.
  - With a constant divisor, `cnt` therefore cycles 0, 1, ..., N-1, 0, ... and `tick` is high
    once every N cycles (when `cnt == N-1`).
  - If `div` is reduced so that `cnt` is already at or beyond the new `N - 1`, `tick` is high
    immediately and the counter returns to 0 on the next edge (it must never run up past N-1
    and wrap through 255).
- `clk_out = (cnt < (N >> 1))`: high for the first `floor(N/2)` cycles of each period and low
  for the rest. For even N this is exactly 50% duty; for odd N it is high for `(N-1)/2` cycles
  and low for `(N+1)/2` cycles.
