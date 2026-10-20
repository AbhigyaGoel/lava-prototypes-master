# crc8

Byte-wise CRC-8 engine (CRC-8/SMBUS parameters).

## Parameters of the CRC
- Polynomial: x^8 + x^2 + x + 1 (`0x07`, normal/MSB-first form)
- Initial value: `0x00`
- No input or output reflection, no final XOR.
- Check value: the CRC of the ASCII string `"123456789"` (bytes 0x31..0x39) is `0xF4`.

## Ports
| Port  | Dir | Width | Description |
|-------|-----|-------|-------------|
| clk   | in  | 1     | Rising-edge clock |
| rst_n | in  | 1     | Asynchronous active-low reset |
| clear | in  | 1     | Synchronous clear of the running CRC |
| valid | in  | 1     | `data` holds a byte to be absorbed this cycle |
| data  | in  | 8     | Input byte |
| crc   | out | 8     | Running CRC register |

## Behavior
- While `rst_n` is low, `crc` is `0x00`.
- On each rising edge of `clk`:
  - if `clear` is 1, `crc` becomes `0x00`. `clear` has priority: if `valid` is also 1 in that
    cycle, the byte on `data` is discarded (not absorbed).
  - else if `valid` is 1, `crc` becomes the CRC update of the old `crc` with the full 8-bit byte,
    processed MSB first: `x = crc ^ data`, then repeat 8 times:
    `x = x[7] ? ((x << 1) ^ 8'h07) : (x << 1)` (8-bit arithmetic); the result is the new `crc`.
  - otherwise `crc` holds.
- `crc` therefore always equals the CRC-8 of all bytes absorbed since the last reset/clear.
