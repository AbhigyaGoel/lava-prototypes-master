# Task suite conventions

Each task is a directory `tasks/<task_id>/`:

```
spec.md             plain-English spec of correct behavior (agent-visible)
rtl/<module>.v      BUGGY RTL (agent-visible; the agent must fix this)
tb/tb_visible.v     visible testbench (agent-visible; may be intentionally weak)
hidden/golden.v     correct reference RTL   (NEVER copied into the agent workspace)
hidden/tb_hidden.v  strong hidden testbench (NEVER copied into the agent workspace)
task.json           metadata (below)
```

`gray_counter/` is the reference example. Copy its style.

## task.json

```json
{
  "id": "gray_counter",              // == directory name
  "module": "gray_counter",          // module name == rtl file stem
  "top": "gray_counter",
  "difficulty": "easy|medium|hard",
  "bug_type": "missing_enable",      // primary bug class; join with '+' for two bugs
  "bug_description": "one line, for the report (never shown to the agent)",
  "visible_tb_weak": true,           // true if the buggy RTL PASSES tb_visible
  "equiv_mode": "comb|seq|none",     // comb = combinational SAT miter; seq = equiv_induct + reset-anchored BMC
  "equiv_seq": 10,                   // seq only
  "bmc_depth": 30,                   // seq only
  "reset": {"port": "rst_n", "active": 0},   // seq only; omit if no reset
  "files_in_scope": ["rtl/gray_counter.v"]
}
```

## Testbench rules (both TBs)

- Top module is `tb`, `` `timescale 1ns/1ps ``, plain Verilog-2005/SV-2012 that Icarus accepts with `-g2012`.
- On any mismatch print a line starting with `FAIL:`; count errors.
- At the end print exactly `TEST PASSED` if errors == 0, else `TEST FAILED: <n> errors`, then `$finish`.
- Include a watchdog: `initial begin #<big> $display("ERROR: watchdog timeout"); $finish; end`.
- Use `!==` for comparisons so X/Z count as mismatches.
- Asynchronous resets: start the reset signal *deasserted* and assert it after `#1`, so the
  reset edge actually occurs (an `initial`-time value of 0 produces no negedge).
- The hidden TB must be strong: exhaustive for combinational logic where feasible, otherwise long
  randomized stimulus (fixed `$random` seed behavior is fine) checked against a behavioral reference
  model written inside the TB, plus directed corner cases (reset mid-operation, enables low, wraparound,
  back-pressure, etc).
- The visible TB is what a hurried engineer would write: a few directed checks. For
  `visible_tb_weak: true` tasks it must NOT exercise the bug(s) (buggy RTL passes it).

## Bugs

- Write the golden RTL first, then copy it to `rtl/` and inject 1-2 realistic bugs: off-by-one constant,
  wrong comparison operator, inverted condition, wrong reset value, missing case/default, blocking vs
  non-blocking, wrong bit slice, FSM transition to the wrong state, missing enable condition.
- NO comments that hint at the bug. The buggy file must look like ordinary production RTL.
- The spec must define the correct behavior unambiguously, so a careful engineer reading the spec and the
  RTL can find every bug without seeing the hidden files. Failures must be fair.
- Keep designs 20-150 lines, single module, synthesizable (Yosys must read it for equivalence).

## Validation

`python -m assay.validate_tasks <task_id>` must print `ok` (golden passes both TBs, buggy fails hidden,
golden-vs-golden equivalence proven). Fix any warnings unless they are intentional.
