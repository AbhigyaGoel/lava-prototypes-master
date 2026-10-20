# traffic_light

Traffic-light controller for a main road crossing a side road, with a pedestrian request button
that shortens the main-road green phase.

## Parameters (all durations in clock cycles)
| Name           | Default | Description |
|----------------|---------|-------------|
| MAIN_GREEN_T   | 8       | Normal length of the main-road green phase |
| MAIN_GREEN_MIN | 3       | Minimum length of the main-road green phase when a pedestrian is waiting (1 <= MIN <= MAIN_GREEN_T) |
| MAIN_YELLOW_T  | 2       | Length of the main-road yellow phase |
| SIDE_GREEN_T   | 4       | Length of the side-road green phase |
| SIDE_YELLOW_T  | 3       | Length of the side-road yellow phase |

## Ports
| Port       | Dir | Width | Description |
|------------|-----|-------|-------------|
| clk        | in  | 1     | Rising-edge clock |
| rst_n      | in  | 1     | Asynchronous active-low reset |
| ped_req    | in  | 1     | Pedestrian request (may be a 1-cycle pulse or held) |
| main_light | out | 3     | Main-road light, one-hot `{red, yellow, green}` |
| side_light | out | 3     | Side-road light, one-hot `{red, yellow, green}` |
| walk       | out | 1     | Pedestrian walk signal |

## Phases
The controller cycles through four phases in this order, forever:

| Phase | main_light       | side_light       | walk | Normal length  |
|-------|------------------|------------------|------|----------------|
| MG    | green  (`3'b001`) | red    (`3'b100`) | 0    | MAIN_GREEN_T  |
| MY    | yellow (`3'b010`) | red    (`3'b100`) | 0    | MAIN_YELLOW_T |
| SG    | red    (`3'b100`) | green  (`3'b001`) | 1    | SIDE_GREEN_T  |
| SY    | red    (`3'b100`) | yellow (`3'b010`) | 0    | SIDE_YELLOW_T |

MG -> MY -> SG -> SY -> MG -> ... The outputs are a function of the current phase only.

## Behavior
- Reset puts the controller at the start of MG (phase timer 0) with no pedestrian request pending.
- A phase "lasts N cycles" means its outputs are present for exactly N consecutive clock cycles:
  the controller keeps an internal phase timer that is 0 in the first cycle of a phase and counts up
  by 1 per cycle; it moves to the next phase on the rising edge at which the timer equals N-1.
- **Pedestrian request**: an internal `ped_pending` flag is set on every rising edge where
  `ped_req = 1`. It is cleared on the rising edge where the controller enters SG (pedestrians cross
  during SG) — except that if `ped_req = 1` on that same edge, the new request wins and the flag
  stays set (it will then shorten the next MG).
- **Shortening**: on a rising edge in MG, the controller leaves MG (to MY) if either
  - the timer equals MAIN_GREEN_T-1 (normal end), or
  - `ped_pending` (its value before the edge) is 1 and the timer is **greater than or equal to**
    MAIN_GREEN_MIN-1.
  So a request that is already pending makes MG last exactly MAIN_GREEN_MIN cycles, and a request
  that becomes pending later in MG (timer already past MAIN_GREEN_MIN-1) ends MG on the very next edge.
- MY, SG and SY always last exactly MAIN_YELLOW_T, SIDE_GREEN_T and SIDE_YELLOW_T cycles respectively;
  `ped_req` does not affect them.
- Example (defaults): `ped_req` pulsed in the first cycle of MG -> pending from the 2nd cycle -> MG lasts 3 cycles.
  `ped_req` pulsed in the 6th cycle of MG (timer = 5) -> pending from timer 6 -> MG lasts 7 cycles.
