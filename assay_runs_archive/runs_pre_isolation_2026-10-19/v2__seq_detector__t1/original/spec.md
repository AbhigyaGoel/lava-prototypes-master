# seq_detector

A Moore finite-state machine that detects the serial bit pattern `1011` on `din`, with overlapping
matches allowed. The state register must be **one-hot** encoded.

## Ports
| Port  | Dir | Width | Description |
|-------|-----|-------|-------------|
| clk   | in  | 1     | Rising-edge clock |
| rst_n | in  | 1     | Asynchronous active-low reset |
| din   | in  | 1     | Serial input, sampled on each rising edge of `clk` |
| found | out | 1     | Registered detection flag |

## Behavior
- One bit of `din` is sampled at every rising edge of `clk` (there is no enable).
- The FSM tracks the longest suffix of the bits sampled so far (since reset) that is a prefix of
  `1011`. States (one-hot): `IDLE` (no useful prefix), `S1` ("1"), `S10` ("10"), `S101` ("101"),
  `S1011` (full match).
- Matches overlap: the trailing bits of one match may begin the next. For example the input
  stream `1011011` produces two matches, and `10101011` produces a match at its last bit
  (the `101` inside `1010` must not be thrown away).
- `found` is a flip-flop. After the rising edge at which the final `1` of a `1011` pattern is
  sampled, `found` is 1 for that clock cycle (i.e. `found` is 1 exactly while the FSM is in
  `S1011`); otherwise it is 0.
- While `rst_n` is low the FSM is in `IDLE` and `found` is 0. Bits sampled before reset are
  forgotten.
- A state value that is not one of the five legal one-hot codes transitions to `IDLE` on the next clock.
