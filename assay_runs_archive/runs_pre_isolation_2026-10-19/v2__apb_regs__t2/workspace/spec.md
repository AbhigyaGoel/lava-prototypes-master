# apb_regs

APB3 slave register block with four 32-bit registers: a control register, a read-only status
register, a write-1-to-clear interrupt status register and an interrupt enable register.

## Ports
| Port      | Dir | Width | Description |
|-----------|-----|-------|-------------|
| pclk      | in  | 1     | Rising-edge clock |
| presetn   | in  | 1     | Asynchronous active-low reset |
| psel      | in  | 1     | APB select |
| penable   | in  | 1     | APB enable (access phase) |
| pwrite    | in  | 1     | 1 = write transfer, 0 = read transfer |
| paddr     | in  | 8     | Byte address |
| pwdata    | in  | 32    | Write data |
| prdata    | out | 32    | Read data (combinational) |
| pready    | out | 1     | Always 1 (no wait states) |
| pslverr   | out | 1     | Slave error (combinational) |
| hw_status | in  | 4     | Live hardware status, reflected in STATUS |
| hw_event  | in  | 4     | Hardware interrupt event inputs (sampled every clock) |
| ctrl_out  | out | 8     | Current value of CTRL[7:0] |
| irq       | out | 1     | Interrupt request (combinational from registers) |

## APB protocol
1. A transfer has a setup phase (`psel=1, penable=0`) followed by an access phase
   (`psel=1, penable=1`). `pready` is always 1, so every access phase lasts exactly one cycle.
2. Let `access = psel && penable`. A **write** takes effect at the rising edge of `pclk` at the end
   of a cycle where `access && pwrite`. Nothing is written in the setup phase or when `psel=0`.
3. `prdata` is combinational. During a cycle with `access && !pwrite` it carries the value of the
   register addressed by `paddr` (formatted as in the register map below). In every other cycle
   (setup phase, idle, write access) and for unmapped addresses, `prdata = 32'h0`.
   Reads have no side effects.
4. `paddr` is decoded on all 8 bits. Only the four addresses `8'h00, 8'h04, 8'h08, 8'h0C` are
   mapped; every other address (including unaligned ones) is unmapped.
5. `pslverr = access && (paddr is unmapped)`, for both reads and writes; it is 0 outside access
   phases. Writes to unmapped addresses change nothing. A write to the read-only STATUS register is
   ignored and is **not** an error (`pslverr = 0`).

## Register map
Unlisted bits are reserved: they read as 0 and writes to them are ignored.

| Addr  | Name       | Access | Reset      | Fields |
|-------|------------|--------|------------|--------|
| 0x00  | CTRL       | RW     | 0x00000010 | [0] EN, [2:1] MODE, [3] reserved, [7:4] DIV |
| 0x04  | STATUS     | RO     | -          | [3:0] HW_STATUS, [4] EN, [5] IRQ |
| 0x08  | INT_STATUS | RW1C   | 0x00000000 | [3:0] pending interrupt flags |
| 0x0C  | INT_EN     | RW     | 0x00000000 | [3:0] interrupt enables |

## Register behavior
6. **CTRL**: a write stores `pwdata[7:4]` into DIV and `pwdata[2:0]` into MODE/EN. Bit 3 is reserved:
   it always reads 0, whatever was written. `ctrl_out` always equals the CTRL value as read
   (`ctrl_out[3] = 0`).
7. **STATUS** (read-only, not a stored register): `STATUS[3:0] = hw_status` (live input value),
   `STATUS[4] = CTRL.EN` (CTRL bit 0), `STATUS[5]` = the current value of the `irq` output as
   defined in rule 10. Bits [31:6] read 0.
8. **INT_STATUS**: at every rising edge of `pclk`, for each bit `i`:
   - if `hw_event[i] = 1`, `INT_STATUS[i]` becomes 1 (an event sets the flag, independent of INT_EN);
   - otherwise, if this cycle is a write access to 0x08 with `pwdata[i] = 1`, `INT_STATUS[i]`
     becomes 0 (write-1-to-clear);
   - otherwise it holds. Writing 0 to a bit has no effect.
   **Priority:** if a hardware event and a software clear hit the same bit in the same cycle, the
   **set wins** and the bit is 1 afterwards, so no event is ever lost. Equivalently:
   `INT_STATUS_next = (INT_STATUS & ~clear_mask) | hw_event`.
9. **INT_EN**: plain read/write register, `pwdata[3:0]`.
10. **irq** = `|(INT_STATUS & INT_EN)` (combinational from the two registers; a pending flag
    whose enable is 0 does not raise `irq`).
11. While `presetn` is low, all registers take their reset values (CTRL = 0x10, others 0).
