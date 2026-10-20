# width_packer

Packs a stream of 8-bit input beats into 32-bit output words, little-endian (the first byte of a
word goes to bits [7:0]). A beat flagged `in_last` closes the current word early: the word is
emitted with the unused upper bytes set to zero and `out_keep` marking the valid bytes. Both sides
use valid/ready handshakes with full back-pressure. The packer must never drop, duplicate or
reorder bytes under any pattern of `in_valid`, `in_last` and `out_ready`.

## Ports
| Port      | Dir | Width | Description |
|-----------|-----|-------|-------------|
| clk       | in  | 1     | Rising-edge clock |
| rst_n     | in  | 1     | Asynchronous active-low reset |
| in_valid  | in  | 1     | Input beat available |
| in_ready  | out | 1     | Packer accepts the input beat this cycle (combinational) |
| in_data   | in  | 8     | Input byte |
| in_last   | in  | 1     | This byte is the last of a packet |
| out_valid | out | 1     | Output word available (registered) |
| out_ready | in  | 1     | Sink accepts the output word this cycle |
| out_data  | out | 32    | Output word (registered) |
| out_keep  | out | 4     | Byte-valid mask, bit i covers `out_data[8i+7:8i]` (registered) |
| out_last  | out | 1     | Word ends a packet (registered) |

## Structure
- An **accumulator** holds 0 to 3 bytes of the word being assembled; let `count` be how many.
- An **output register** holds at most one complete word (`out_valid`, `out_data`, `out_keep`,
  `out_last`). `out_data`/`out_keep`/`out_last` are only meaningful while `out_valid = 1`.

## Rules
All edges are rising edges of `clk`. "Accepted" means `in_valid && in_ready` in the cycle before
the edge; "delivered" means `out_valid && out_ready` in the cycle before the edge.

1. **Reset.** While `rst_n` is low: `out_valid = 0`, accumulator empty (`count = 0`).
2. **Closing beat.** An input beat *closes* a word if `count == 3` or `in_last == 1`.
3. **Ready.** `in_ready = (out_valid == 0) || (out_ready == 1) || (count != 3 && in_last == 0)`.
   That is, a non-closing beat is always accepted; a closing beat is accepted only if the output
   register is empty or is being delivered in the same cycle.
4. **Non-closing beat accepted.** The byte is stored as byte number `count` of the current word and
   `count` increments.
5. **Closing beat accepted.** The output register is loaded with the word made of the `count` held
   bytes (bytes 0..count-1) and the incoming byte as byte number `count`; all higher bytes are 0.
   `out_keep` has bits 0..count set (`count` = 0,1,2,3 gives `0001`, `0011`, `0111`, `1111`),
   `out_last = in_last`, `out_valid <= 1`, and the accumulator becomes empty (`count <= 0`).
   A fourth byte that also has `in_last = 1` gives `out_keep = 1111`, `out_last = 1`.
6. **Delivery.** When a word is delivered and no closing beat is accepted in the same cycle,
   `out_valid <= 0`. If a word is delivered **and** a closing beat is accepted in the same cycle,
   the new word replaces it: `out_valid` stays 1 with the new contents. This allows one word per
   cycle (e.g. a stream of 1-byte packets with `out_ready` held high).
7. **Ordering.** Words are delivered in the order they were formed; across all delivered words,
   the bytes covered by `out_keep` are exactly the accepted input bytes, in order.

## Example
Input bytes `11 22 33` (with `in_last` on `33`) produce `out_data = 32'h00332211`,
`out_keep = 4'b0111`, `out_last = 1`. Input bytes `10 11 12 13 14 15` (with `in_last` on `15`) produce
`32'h13121110 / 1111 / 0` then `32'h00001514 / 0011 / 1`.
