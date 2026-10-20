# regfile

An 8-entry x 8-bit register file with two asynchronous (combinational) read ports and one
synchronous write port. Register 0 is hardwired to zero.

## Ports
| Port   | Dir | Width | Description |
|--------|-----|-------|-------------|
| clk    | in  | 1     | Rising-edge clock |
| rst_n  | in  | 1     | Asynchronous active-low reset |
| we     | in  | 1     | Write enable |
| waddr  | in  | 3     | Write address |
| wdata  | in  | 8     | Write data |
| raddr1 | in  | 3     | Read address, port 1 |
| rdata1 | out | 8     | Read data, port 1 (combinational) |
| raddr2 | in  | 3     | Read address, port 2 |
| rdata2 | out | 8     | Read data, port 2 (combinational) |

## Behavior
- While `rst_n` is low, registers 1..7 are cleared to 0.
- Write: on a rising edge of `clk` with `we == 1` and `waddr != 0`, register `waddr` takes `wdata`.
  Writes with `waddr == 0` have no effect. When `we == 0`, nothing is written (regardless of
  `waddr`/`wdata`).
- Read (each port independently, identical rules for port 1 and port 2), combinationally from the
  current inputs and register contents, in this priority order:
  1. If `raddrN == 0`: `rdataN = 8'h00`, always (even if a write to register 0 is being requested
     in the same cycle).
  2. Else, if `we == 1` and `waddr == raddrN` (write-to-read bypass): `rdataN = wdata`, i.e. a
     read of the register being written in the current cycle returns the new value.
  3. Else: `rdataN` = the stored value of register `raddrN`.
- The bypass in rule 2 applies **only** when `we` is 1.
