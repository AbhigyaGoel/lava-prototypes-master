# uart_tx

UART transmitter, 8N1 framing (1 start bit, 8 data bits LSB first, no parity, 1 stop bit).

## Parameters
| Name         | Default | Description |
|--------------|---------|-------------|
| CLKS_PER_BIT | 4       | Clock cycles per bit period (>= 2) |

## Ports
| Port     | Dir | Width | Description |
|----------|-----|-------|-------------|
| clk      | in  | 1     | Rising-edge clock |
| rst_n    | in  | 1     | Asynchronous active-low reset |
| tx_start | in  | 1     | Request to send `tx_data` |
| tx_data  | in  | 8     | Byte to send (sampled together with an accepted `tx_start`) |
| tx       | out | 1     | Serial line (registered); idles high |
| busy     | out | 1     | 1 while a frame is being transmitted (registered) |

## Behavior
- While `rst_n` is low: `tx = 1` (line idle/high) and `busy = 0`. After reset the line stays high
  until a frame is started.
- The transmitter is **idle** exactly when `busy = 0`. On a rising edge where it is idle and
  `tx_start = 1`, the request is **accepted**: `tx_data` is captured, and on that same edge `tx`
  goes to 0 (start bit) and `busy` goes to 1.
- `tx_start` (and `tx_data`) are ignored on every edge where `busy = 1`. A new request during a
  frame does not affect the frame in progress, is not queued, and does not change the byte being sent.
- Frame timing, counting rising edges from the accepting edge E0 (C = CLKS_PER_BIT):
  - start bit (`tx = 0`) from E0 until E(C);
  - data bit k (k = 0..7, LSB first, i.e. `tx_data[k]` as captured at E0) from E((k+1)*C) until E((k+2)*C);
  - stop bit (`tx = 1`) from E(9*C) until E(10*C);
  - at E(10*C) `busy` returns to 0 and `tx` stays 1.
  Every bit, including the stop bit, lasts exactly C clock cycles; `busy` is high for exactly 10*C cycles.
- Because requests are only accepted while `busy = 0`, a `tx_start` held continuously high produces
  back-to-back frames separated by exactly one idle cycle (the next frame is accepted at E(10*C + 1)).
- When idle, `tx` remains 1.
