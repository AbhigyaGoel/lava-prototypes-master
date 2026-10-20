# mod10_counter

A 4-bit BCD (mod-10) up counter with synchronous load, count enable, and a carry-out.

## Ports
| Port  | Dir | Width | Description |
|-------|-----|-------|-------------|
| clk   | in  | 1     | Rising-edge clock |
| rst_n | in  | 1     | Asynchronous active-low reset |
| en    | in  | 1     | Count enable |
| load  | in  | 1     | Synchronous load (has priority over `en`) |
| d     | in  | 4     | Load value |
| q     | out | 4     | Current count, 0..9 (registered) |
| co    | out | 1     | Carry-out (combinational) |

## Behavior
- While `rst_n` is low, `q` is 0.
- On a rising edge of `clk` with `load` high, `q` takes `d`. If `d` is greater than 9 (not a
  valid BCD digit), `q` takes 0 instead. `load` works regardless of `en`.
- Otherwise, on a rising edge with `en` high, `q` increments by 1, wrapping 9 -> 0.
- Otherwise `q` holds.
- `co` is a combinational signal that is high exactly when the *next* rising edge will
  perform a counting wrap from 9 to 0, i.e. `co = en && !load && (q == 9)`.
  It is low at all other times (in particular, it is low whenever `load` is high).
- `q` never holds a value above 9.
