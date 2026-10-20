# timer_irq

A 16-bit down-counting timer with a load value, count enable, optional auto-reload and a sticky
interrupt flag with a write-1-to-clear input.

## Ports
| Port        | Dir | Width | Description |
|-------------|-----|-------|-------------|
| clk         | in  | 1     | Rising-edge clock |
| rst_n       | in  | 1     | Asynchronous active-low reset |
| load        | in  | 1     | Load strobe |
| load_val    | in  | 16    | Value loaded when `load` is 1 |
| en          | in  | 1     | Count enable |
| auto_reload | in  | 1     | 1: periodic mode; 0: one-shot mode |
| irq_clr     | in  | 1     | Write-1-to-clear for `irq` |
| count       | out | 16    | Current counter value (registered) |
| irq         | out | 1     | Sticky interrupt flag (registered) |

## State
- `count` (16 bits), an internal 16-bit **reload register**, and `irq`.
- While `rst_n` is low: `count = 0`, reload register = 0, `irq = 0`.

## Counter (evaluated at each rising edge of `clk`, in priority order)
1. If `load == 1`: `count <= load_val` and reload register `<= load_val`. No expiry occurs in this
   cycle, regardless of `en` and the current count.
2. Else if `en == 1` and `count != 0`:
   - If `count == 1` this cycle is an **expiry**:
     - `auto_reload == 1`: `count <= reload register` (the value given at the most recent load).
     - `auto_reload == 0`: `count <= 0` (timer stops at 0).
   - Otherwise `count <= count - 1`.
3. Else (`en == 0`, or `count == 0`): `count` holds. A timer at 0 never expires and never wraps.

Consequently, after a load of N (N >= 1) with `en` held high, the first expiry happens on the N-th
enabled clock edge after the load, and in auto-reload mode every subsequent expiry happens exactly
N enabled clock edges after the previous one (period N; with N = 1 the timer expires every enabled cycle).

## Interrupt flag
- On an expiry edge, `irq <= 1`.
- Otherwise, if `irq_clr == 1`, `irq <= 0`.
- Otherwise `irq` holds (sticky).
- **Set has priority over clear**: if an expiry and `irq_clr` happen at the same edge, `irq` is 1
  after that edge.
