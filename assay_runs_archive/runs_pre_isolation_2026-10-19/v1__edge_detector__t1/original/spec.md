# edge_detector

Detects rising and falling edges of an asynchronous input after synchronizing it into the
`clk` domain with a 2-flop synchronizer.

## Ports
| Port  | Dir | Width | Description |
|-------|-----|-------|-------------|
| clk   | in  | 1     | Rising-edge clock |
| rst_n | in  | 1     | Asynchronous active-low reset |
| din   | in  | 1     | Asynchronous input |
| rise  | out | 1     | One-cycle pulse on a synchronized 0 -> 1 transition |
| fall  | out | 1     | One-cycle pulse on a synchronized 1 -> 0 transition |
| any   | out | 1     | One-cycle pulse on either transition |

## Structure / timing (normative)
- Three registers, **all reset to 0** while `rst_n` is low, all updated on every rising edge of `clk`:
  - `sync1 <= din`
  - `sync2 <= sync1`   (`sync2` is the synchronized version of `din`)
  - `prev  <= sync2`   (`sync2` delayed one cycle)
- Outputs are combinational functions of `sync2` and `prev`:
  - `rise = sync2 & ~prev`
  - `fall = ~sync2 & prev`
  - `any  = sync2 ^ prev`
- Consequently, if `din` changes and is stable across rising edges, it is captured into `sync1`
  at edge k, into `sync2` at edge k+1, and the corresponding pulse is high from edge k+1 until
  edge k+2 (exactly one clock cycle).
- Immediately after reset (all registers 0) no output pulses until `din` has been
  synchronized; e.g. if `din` stays 0 through and after reset, `rise`, `fall` and `any` stay 0.
