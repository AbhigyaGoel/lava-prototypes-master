# pwm

An 8-bit pulse-width-modulation generator with a period of 256 clock cycles.

## Ports
| Port    | Dir | Width | Description |
|---------|-----|-------|-------------|
| clk     | in  | 1     | Rising-edge clock |
| rst_n   | in  | 1     | Asynchronous active-low reset |
| duty    | in  | 8     | Requested duty cycle (number of high cycles per 256-cycle period) |
| pwm_out | out | 1     | PWM output (combinational from registers) |

## Behavior
- Internal registers: a free-running 8-bit counter `cnt` and an 8-bit latched duty value `duty_q`.
- While `rst_n` is low, `cnt = 0` and `duty_q = 0`.
- On every rising edge of `clk`, `cnt` increments by 1, wrapping 255 -> 0.
- `duty_q` only changes at the period boundary: on the rising edge at which `cnt` goes from
  255 to 0, `duty_q` takes the value of `duty` sampled at that edge. At every other edge `duty_q`
  holds. Changes to `duty` in the middle of a period therefore have no effect until the next
  period begins, and the new value applies starting from the cycle in which `cnt == 0`.
- `pwm_out = (cnt < duty_q)`. So in each period the output is high for exactly `duty_q`
  cycles (cnt = 0 .. duty_q-1) and low for the remaining `256 - duty_q` cycles. `duty_q = 0`
  means the output is low for the whole period; `duty_q = 255` means high for 255 of 256 cycles.
- Because `duty_q` resets to 0, the output is low for the entire first period after reset
  (cnt = 0..255), regardless of `duty`.
