# seg7_decoder

Combinational hexadecimal (0-F) to 7-segment display decoder with active-low outputs.

## Ports
| Port  | Dir | Width | Description |
|-------|-----|-------|-------------|
| hex   | in  | 4     | Hex digit to display (0x0-0xF) |
| blank | in  | 1     | When 1, all segments are turned off |
| seg   | out | 7     | Segment drives, **active-low**: `seg[0]`=a, `seg[1]`=b, `seg[2]`=c, `seg[3]`=d, `seg[4]`=e, `seg[5]`=f, `seg[6]`=g |

Segment layout (standard): a = top, b = upper right, c = lower right, d = bottom,
e = lower left, f = upper left, g = middle.

## Behavior
- Purely combinational, no clock.
- When `blank` is 1, `seg` = `7'b1111111` (every segment off), regardless of `hex`.
- When `blank` is 0, a segment's bit is 0 (lit) if it is in the lit set below, else 1 (off):

| hex | glyph | lit segments  |
|-----|-------|---------------|
| 0   | 0     | a b c d e f   |
| 1   | 1     | b c           |
| 2   | 2     | a b d e g     |
| 3   | 3     | a b c d g     |
| 4   | 4     | b c f g       |
| 5   | 5     | a c d f g     |
| 6   | 6     | a c d e f g   |
| 7   | 7     | a b c         |
| 8   | 8     | a b c d e f g |
| 9   | 9     | a b c d f g   |
| A   | A     | a b c e f g   |
| B   | b     | c d e f g     |
| C   | C     | a d e f       |
| D   | d     | b c d e g     |
| E   | E     | a d e f g     |
| F   | F     | a e f g       |

Example: `hex=4'h1, blank=0` gives `seg = 7'b1111001`.
