# int_ctrl

8-source interrupt controller with per-source trigger mode (level / edge), an enable mask, a
pending register, fixed priority (lowest source index wins) and an acknowledge input.

## Ports
| Port    | Dir | Width | Description |
|---------|-----|-------|-------------|
| clk     | in  | 1     | Rising-edge clock |
| rst_n   | in  | 1     | Asynchronous active-low reset |
| src     | in  | 8     | Interrupt source lines (already synchronous to `clk`); `src[i]` = source i |
| we      | in  | 1     | Register write strobe |
| addr    | in  | 2     | Register address |
| wdata   | in  | 8     | Register write data |
| ack     | in  | 1     | Acknowledge strobe |
| ack_id  | in  | 3     | Source index being acknowledged (meaningful when `ack = 1`) |
| pending | out | 8     | Pending vector (combinational, see rule 5) |
| irq     | out | 1     | Interrupt request (combinational) |
| irq_id  | out | 3     | Index of the highest-priority active source (combinational) |

## Registers
| addr | Name | Reset | Description |
|------|------|-------|-------------|
| 0    | MASK | 0x00  | `MASK[i] = 1` enables source i to raise `irq` |
| 1    | MODE | 0x00  | `MODE[i] = 0`: source i is level-triggered; `1`: rising-edge-triggered |
| 2, 3 | -    | -     | Reserved: writes are ignored |

## Rules
1. **Register writes.** On a rising edge of `clk` with `we = 1`, the register selected by `addr` is
   loaded with `wdata`. A write takes effect from the next cycle; every rule below that refers to
   `MASK` or `MODE` uses the register value held *during* the current cycle (before the write).
2. **Edge detection.** The controller keeps `src_q`, a copy of `src` registered on every rising
   edge of `clk` (reset value 0), regardless of `MODE`. Source i has a *rising edge* in a cycle iff
   `src[i] = 1` and `src_q[i] = 0` in that cycle.
3. **Edge-pending register.** An internal register `edge_pend[7:0]` (reset 0) is updated on every
   rising edge of `clk`, per bit i, with the following priority (first matching line wins):
   1. `MODE[i] = 0` (level source): `edge_pend[i] <= 0`. Edge-pending bits of level-mode sources
      are always held at 0, so a source switched from level to edge mode starts with nothing
      pending, whatever its line did while it was in level mode.
   2. Source i has a rising edge this cycle: `edge_pend[i] <= 1` (also when the same source is
      acknowledged in the same cycle).
   3. `ack = 1` and `ack_id = i`: `edge_pend[i] <= 0`.
   4. Otherwise `edge_pend[i]` holds.
4. **Acknowledge** affects only the edge-pending bit selected by `ack_id`. It is honoured whatever
   the current `irq_id`, `MASK` or `pending` value is. Acknowledging a level-mode source has no
   effect (a level source stays pending as long as its line is high).
5. **Pending.** `pending[i] = edge_pend[i]` if `MODE[i] = 1`, else `pending[i] = src[i]`
   (level sources follow their line combinationally). Pending is independent of `MASK`.
6. **Active / irq.** `active = pending & MASK`. `irq = 1` iff `active != 0`.
7. **Priority.** `irq_id` is the **lowest** index i with `active[i] = 1` (source 0 has the highest
   priority). When `active = 0`, `irq_id = 0`.
8. While `rst_n` is low all registers (`MASK`, `MODE`, `src_q`, `edge_pend`) are 0.

## Example
`MODE = 0x0F`, `MASK = 0xFF`. Source 2 rises -> next cycle `pending = 0x04`, `irq = 1`,
`irq_id = 2`. In a cycle with `ack = 1, ack_id = 2` and `src[2]` low, `pending[2]` is 0 from the
next cycle. Level source 5 high together with pending edge source 2 gives `irq_id = 2`.
