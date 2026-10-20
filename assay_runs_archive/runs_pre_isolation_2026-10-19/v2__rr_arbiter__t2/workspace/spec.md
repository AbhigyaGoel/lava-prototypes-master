# rr_arbiter

4-requester round-robin arbiter with a one-hot grant and a rotating priority pointer.

## Ports
| Port  | Dir | Width | Description |
|-------|-----|-------|-------------|
| clk   | in  | 1     | Rising-edge clock |
| rst_n | in  | 1     | Asynchronous active-low reset |
| req   | in  | 4     | Request lines, `req[i]` = requester i wants the resource |
| grant | out | 4     | One-hot grant (combinational from `req` and the internal pointer) |

## Behavior
- The arbiter holds a 2-bit priority pointer `ptr` (internal register). Reset sets `ptr = 0`.
- `grant` is combinational: starting at requester `ptr` and searching upward with wrap-around
  (`ptr, ptr+1, ptr+2, ptr+3`, all modulo 4), the first requester `i` with `req[i] = 1` is granted:
  `grant = 1 << i`. If `req == 0`, `grant = 0`. `grant` is never more than one-hot.
- On each rising edge of `clk`, if some requester is granted (i.e. `req != 0`), the pointer moves
  to one past the granted requester: `ptr <= (i + 1) mod 4`. If `req == 0`, `ptr` holds.
- Consequently, the requester just granted has the lowest priority in the next cycle, and with all
  four requesting continuously the grant rotates 0, 1, 2, 3, 0, ...
- Example: `ptr = 2`, `req = 4'b0011` -> the search order is 2, 3, 0, 1, so requester 0 is granted
  (`grant = 4'b0001`) and `ptr` becomes 1.
