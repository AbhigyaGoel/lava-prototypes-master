# alu

An 8-bit combinational ALU with eight operations and three status flags.

## Ports
| Port     | Dir | Width | Description |
|----------|-----|-------|-------------|
| a        | in  | 8     | Operand A |
| b        | in  | 8     | Operand B |
| op       | in  | 3     | Operation select (table below) |
| y        | out | 8     | Result |
| zero     | out | 1     | 1 iff `y == 8'h00` (for every opcode) |
| carry    | out | 1     | Carry / borrow flag (see below) |
| overflow | out | 1     | Signed (two's-complement) overflow flag (see below) |

The module is purely combinational (no clock).

## Operations
| op  | Name | y |
|-----|------|---|
| 000 | ADD  | `a + b` (low 8 bits) |
| 001 | SUB  | `a - b` (low 8 bits) |
| 010 | AND  | `a & b` |
| 011 | OR   | `a \| b` |
| 100 | XOR  | `a ^ b` |
| 101 | SLL  | `a` shifted left logically by `b[2:0]` (zeros shifted in); `b[7:3]` ignored |
| 110 | SRL  | `a` shifted right logically by `b[2:0]` (zeros shifted in); `b[7:3]` ignored |
| 111 | SLT  | `8'h01` if `a < b` when **both are interpreted as signed two's-complement** 8-bit numbers, else `8'h00` |

## Flags
- `zero`: 1 iff `y` is all zeros, for every opcode.
- `carry`:
  - ADD: the carry out of bit 7 of the unsigned 9-bit sum `a + b`.
  - SUB: the borrow, i.e. 1 iff `a < b` as **unsigned** numbers.
  - all other opcodes: 0.
- `overflow` (signed overflow):
  - ADD: 1 iff the true signed sum of `a` and `b` (as signed values) is outside -128..127.
    Equivalently `a[7] == b[7]` and `y[7] != a[7]`.
  - SUB: 1 iff the true signed difference `a - b` (as signed values) is outside -128..127.
    Equivalently `a[7] != b[7]` and `y[7] != a[7]`.
  - all other opcodes: 0.
