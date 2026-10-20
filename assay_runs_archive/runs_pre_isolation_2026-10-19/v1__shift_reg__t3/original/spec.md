# shift_reg

An 8-bit bidirectional shift register with synchronous parallel load, serial input and serial output.

## Ports
| Port  | Dir | Width | Description |
|-------|-----|-------|-------------|
| clk   | in  | 1     | Rising-edge clock |
| rst_n | in  | 1     | Asynchronous active-low reset |
| en    | in  | 1     | Shift enable |
| load  | in  | 1     | Synchronous parallel load |
| dir   | in  | 1     | Shift direction: 0 = left (toward bit 7), 1 = right (toward bit 0) |
| sin   | in  | 1     | Serial input |
| d     | in  | 8     | Parallel load data |
| q     | out | 8     | Register contents (registered) |
| sout  | out | 1     | Serial output (combinational) |

## Behavior
- While `rst_n` is low, `q` is 0.
- On a rising edge of `clk`, in priority order:
  1. If `load` is high, `q <= d`. **`load` does not depend on `en`**: a load happens whenever
     `load` is high, whether `en` is high or low.
  2. Else if `en` is high and `dir` is 0 (shift left): `q <= {q[6:0], sin}`.
  3. Else if `en` is high and `dir` is 1 (shift right): `q <= {sin, q[7:1]}`.
  4. Otherwise `q` holds.
- `sout` is the bit that will be shifted out by the next shift in the currently selected
  direction: `sout = q[7]` when `dir` is 0, and `sout = q[0]` when `dir` is 1. It depends only
  on `q` and `dir` (not on `en` or `load`).
