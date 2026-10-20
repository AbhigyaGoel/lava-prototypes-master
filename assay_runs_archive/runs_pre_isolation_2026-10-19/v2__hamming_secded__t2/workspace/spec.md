# hamming_secded

Combinational SECDED (single-error-correct, double-error-detect) decoder for an extended
Hamming(12,8) code: 8 data bits, 4 Hamming parity bits and 1 overall parity bit = 13-bit codeword.

## Ports
| Port       | Dir | Width | Description |
|------------|-----|-------|-------------|
| cw         | in  | 13    | Received codeword |
| data       | out | 8     | Decoded (corrected when possible) data |
| single_err | out | 1     | A single-bit error was detected and corrected |
| double_err | out | 1     | An uncorrectable error was detected |
| err_pos    | out | 4     | Position of the corrected bit (see Decoding rules) |

## Codeword layout
Bit `cw[j]` is "position j". Positions 1..12 form the Hamming(12,8) code; position 0 is the
overall parity bit.

| Position | 0  | 1  | 2  | 3  | 4  | 5  | 6  | 7  | 8  | 9  | 10 | 11 | 12 |
|----------|----|----|----|----|----|----|----|----|----|----|----|----|----|
| Content  | P0 | P1 | P2 | d0 | P4 | d1 | d2 | d3 | P8 | d4 | d5 | d6 | d7 |

- Hamming parity bit `Pk` (k = 1, 2, 4, 8) sits at position k and makes the XOR of all positions
  j in 1..12 with `(j & k) != 0` (including position k itself) equal to 0 (even parity).
- `P0` makes the XOR of all 13 bits `cw[12:0]` equal to 0 (even overall parity).
- `data[i]` = `d_i` (so `data[0]` comes from position 3 and `data[7]` from position 12).

## Decoding rules
Let `syn` (4 bits) be the XOR of the position numbers j (1..12) of all bits with `cw[j] = 1`;
equivalently `syn[b]` = XOR of `cw[j]` over j in 1..12 with bit b of j set. Let `parity = ^cw`
(XOR of all 13 bits).

1. `syn = 0`, `parity = 0`: no error. `single_err = 0`, `double_err = 0`, `err_pos = 0`,
   `data` = the data positions of `cw`.
2. `parity = 1`, `syn` in 1..12: single error at position `syn`. `single_err = 1`,
   `double_err = 0`, `err_pos = syn`. `data` is taken from `cw` with bit `syn` inverted (so data
   is corrected when `syn` is a data position, and unchanged when it is a parity position).
3. `parity = 1`, `syn = 0`: single error in the overall parity bit P0. `single_err = 1`,
   `double_err = 0`, `err_pos = 0`, `data` = the data positions of `cw`.
4. `parity = 1`, `syn` in 13..15: no single-bit error can produce this (positions only go up to
   12), so it is an uncorrectable multi-bit error: `single_err = 0`, `double_err = 1`,
   `err_pos = 0`, `data` = the data positions of `cw` (uncorrected).
5. `parity = 0`, `syn != 0`: double error. `single_err = 0`, `double_err = 1`, `err_pos = 0`,
   `data` = the data positions of `cw` exactly as received; no bit is inverted.

`single_err` and `double_err` are never both 1. `err_pos` is 0 whenever `single_err = 0`.

## Example
`data = 8'hA5` encodes to `cw = 13'h144E` (positions 1, 2, 3, 6, 10, 12 set; `P0 = 0`). The
decoder returns `data = 8'hA5`, `single_err = 0`, `double_err = 0` for `13'h144E`, and
`data = 8'hA5`, `single_err = 1` for `13'h144E` with any one of its 13 bits inverted.
