# sat_adder

An 8-bit signed (two's-complement) saturating adder/subtractor. Purely combinational.

## Ports
| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| a    | in  | 8     | Operand A, signed |
| b    | in  | 8     | Operand B, signed |
| sub  | in  | 1     | 0: compute `a + b`; 1: compute `a - b` |
| y    | out | 8     | Saturated result, signed |
| sat  | out | 1     | 1 iff the result was clamped |

## Behavior
Let `r` be the mathematically exact result (`a + b` or `a - b`, with `a` and `b` interpreted as
signed integers in -128..127; `r` is in -255..255).
- If `r > 127`: `y = 8'h7F` (+127) and `sat = 1`.
- If `r < -128`: `y = 8'h80` (-128) and `sat = 1`.
- Otherwise: `y = r` (two's-complement) and `sat = 0`.

This must hold for every input combination, including `b = -128` with `sub = 1`.
