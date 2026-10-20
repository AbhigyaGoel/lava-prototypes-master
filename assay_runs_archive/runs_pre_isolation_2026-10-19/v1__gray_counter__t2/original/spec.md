# gray_counter

A 4-bit Gray-code counter.

## Ports
| Port    | Dir | Width | Description |
|---------|-----|-------|-------------|
| clk     | in  | 1     | Rising-edge clock |
| rst_n   | in  | 1     | Asynchronous active-low reset |
| en      | in  | 1     | Count enable |
| gray    | out | 4     | Current count, Gray-encoded (registered) |

## Behavior
- While `rst_n` is low, the internal binary count and `gray` are 0.
- On each rising edge of `clk` with `en` high, the internal binary count increments by 1
  (wrapping 15 -> 0) and `gray` takes the Gray encoding of the *new* binary count:
  `gray = bin ^ (bin >> 1)`.
- When `en` is low, the count and `gray` hold their values.
- Consecutive outputs therefore differ in exactly one bit.
