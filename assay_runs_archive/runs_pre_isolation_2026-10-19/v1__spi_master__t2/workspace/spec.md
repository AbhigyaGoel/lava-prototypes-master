# spi_master

SPI bus master. One transfer exchanges one byte in each direction, MSB first, in any of the four
SPI modes (CPOL/CPHA). The serial clock `sclk` is generated from `clk` with a programmable
half-period. All outputs except `mosi` are registered; `mosi` is a combinational function of
registered state.

## Ports
| Port    | Dir | Width | Description |
|---------|-----|-------|-------------|
| clk     | in  | 1     | System clock, rising edge |
| rst_n   | in  | 1     | Asynchronous active-low reset |
| start   | in  | 1     | Transfer request |
| cpol    | in  | 1     | Clock polarity: idle level of `sclk` |
| cpha    | in  | 1     | Clock phase |
| div     | in  | 4     | `sclk` half-period is `div + 1` clk cycles |
| tx_data | in  | 8     | Byte to transmit |
| miso    | in  | 1     | Serial data from the slave |
| sclk    | out | 1     | Serial clock |
| mosi    | out | 1     | Serial data to the slave |
| cs_n    | out | 1     | Active-low chip select |
| busy    | out | 1     | 1 while a transfer is in progress |
| done    | out | 1     | One-cycle pulse when a transfer completes |
| rx_data | out | 8     | Byte received by the most recent completed transfer |

## Mode table
"Leading" is the first `sclk` edge of each bit cell (away from the idle level), "trailing" the second.

| Mode | CPOL | CPHA | Idle `sclk` | Sample `miso` on | Shift `mosi` on |
|------|------|------|-------------|------------------|-----------------|
| 0    | 0    | 0    | low         | rising (leading)  | falling (trailing) |
| 1    | 0    | 1    | low         | falling (trailing)| rising (leading)   |
| 2    | 1    | 0    | high        | falling (leading) | rising (trailing)  |
| 3    | 1    | 1    | high        | rising (trailing) | falling (leading)  |

## Rules
All "edges" below are rising edges of `clk` unless they say `sclk` edge.

1. **Reset.** While `rst_n` is low: `cs_n = 1`, `sclk = 0`, `busy = 0`, `done = 0`, `rx_data = 0`,
   `mosi = 0`, and the latched configuration (rule 2) is CPOL=0, CPHA=0, DIV=0.
2. **Configuration latch.** On every edge where `busy = 0`, the module latches `cpol`, `cpha` and
   `div` into internal registers CPOL_Q, CPHA_Q, DIV_Q. While `busy = 1` these registers hold.
   Consequently a transfer uses the values present on the edge that accepted `start`; changes of
   `cpol`, `cpha` or `div` during a transfer have no effect on that transfer.
3. **Idle clock.** On every edge where `busy = 0`, `sclk` is loaded with `cpol` (so while idle
   `sclk` follows `cpol` one cycle late).
4. **Start.** On an edge where `busy = 0` and `start = 1`, a transfer begins: `busy <= 1`,
   `cs_n <= 0`, `tx_data` is captured as the transmit byte. `start` is ignored while `busy = 1`.
   Note that `busy` is already 0 in the cycle where `done = 1`, so a `start` in that cycle (or a
   `start` held high continuously) begins the next transfer immediately.
5. **Bit timing.** Let the start edge be edge 0 and D = DIV_Q. During the transfer, *ticks* occur at
   edges n·(D+1) for n = 1, 2, ..., 17 (counted from the start edge). Ticks 1 through 16 each
   toggle `sclk` (sclk edges 1..16; odd = leading, even = trailing). Tick 17 ends the transfer
   (rule 8). Nothing else changes `sclk`, `mosi` or the receive register between ticks.
6. **Transmit.** While `cs_n = 1`, `mosi = 0`. While `cs_n = 0`, `mosi` shows bit (7 - s) of the
   transmit byte, where s is the number of shift events so far in this transfer (`mosi` = 0 once
   s = 8). So bit 7 is on `mosi` as soon as `cs_n` falls. A shift event happens on every `sclk` edge
   of the "shift" kind for the current mode (table above), **except sclk edge 1**, which never
   shifts. (Modes 0/2 therefore shift on edges 2,4,...,16; modes 1/3 on edges 3,5,...,15.)
7. **Receive.** On every `sclk` edge of the "sample" kind for the current mode, the value of `miso`
   present just before that tick's clock edge is shifted into an 8-bit receive register from the
   LSB side (`rx = {rx[6:0], miso}`), so the first sampled bit ends up as bit 7.
8. **Completion.** At tick 17: `cs_n <= 1`, `busy <= 0`, `done <= 1` for exactly one cycle, and
   `rx_data <=` the receive register. `sclk` is at the idle level CPOL_Q at this point (16 toggles).
   `rx_data` holds its value until the next completion.

## Example (mode 0, div = 1)
`start` accepted at edge 0. `cs_n` falls, `mosi` = bit 7. `sclk` rises at edge 2 (sample bit 7 of
`miso`), falls at edge 4 (mosi -> bit 6), ..., the 16th `sclk` edge is at edge 32, and at edge 34
`cs_n` rises, `busy` falls, `done` pulses and `rx_data` is updated.
