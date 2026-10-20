# priority_encoder

An 8-input combinational priority encoder. The highest-numbered asserted input wins.

## Ports
| Port  | Dir | Width | Description |
|-------|-----|-------|-------------|
| in    | in  | 8     | Request inputs; bit 7 has the highest priority |
| y     | out | 3     | Index of the highest-numbered bit of `in` that is 1 |
| valid | out | 1     | High when any bit of `in` is 1 |

## Behavior
- Purely combinational; no clock or reset.
- If `in` is non-zero: `valid = 1` and `y` = the index of the most significant 1 bit of `in`
  (e.g. `in = 8'b0010_1100` gives `y = 5`; `in = 8'b0000_1000` gives `y = 3`).
- If `in` is zero: `valid = 0` and `y = 0`.
- Outputs are never X or Z for any fully-specified input.
