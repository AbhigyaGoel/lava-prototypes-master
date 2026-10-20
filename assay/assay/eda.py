"""Thin wrappers over Icarus Verilog (simulation) and Yosys (formal equivalence)."""
from __future__ import annotations

import re
import shutil
import tempfile
from pathlib import Path

from .common import PASS_MARKER, SIM_TIMEOUT_S, run_cmd, tail

FAIL_RE = re.compile(r"\bFAIL|\bERROR\b|\bmismatch|syntax error|error\(s\)|\bI give up\b", re.IGNORECASE)
SAT_CEX_RE = re.compile(r"proof did fail|model found|\bFAIL\b", re.IGNORECASE)


KIND_MAX_STEPS = 40


def classify_sim_output(text: str) -> str:
    """'pass' | 'fail' | 'unknown' for a simulator log (works on agent-run logs too)."""
    if FAIL_RE.search(text):
        return "fail"
    if PASS_MARKER in text or re.search(r"\ball tests? passed\b", text, re.IGNORECASE):
        return "pass"
    return "unknown"


def simulate(tb: Path, rtl_files: list[Path], timeout: int = SIM_TIMEOUT_S) -> dict:
    """Compile + run a testbench against RTL in a scratch dir. Returns {passed, output_tail, reason}."""
    with tempfile.TemporaryDirectory(prefix="assay_sim_") as tmp:
        work = Path(tmp)
        shutil.copy(tb, work / "tb.v")
        names = []
        for i, f in enumerate(rtl_files):
            dst = work / f"rtl_{i}_{f.name}"
            shutil.copy(f, dst)
            names.append(dst.name)
        code, out = run_cmd(["iverilog", "-g2012", "-o", "sim.vvp", "tb.v", *names], work, timeout)
        if code != 0:
            return {"passed": False, "reason": "compile_error", "output_tail": tail(out)}
        code, run_out = run_cmd(["vvp", "-n", "sim.vvp"], work, timeout)
        out = out + run_out
        if code == -1:
            return {"passed": False, "reason": "timeout", "output_tail": tail(out)}
        verdict = classify_sim_output(run_out)
        passed = code == 0 and verdict == "pass"
        reason = "ok" if passed else ("fail_marker" if verdict == "fail" else "no_pass_marker")
        return {"passed": passed, "reason": reason, "output_tail": tail(out)}


def _read_block(files: list[str], top: str, name: str) -> str:
    reads = "\n".join(f"read_verilog -sv {f}" for f in files)
    return f"""{reads}
hierarchy -check -top {top}
proc; flatten; memory; opt_clean
rename {top} {name}
design -stash {name}
"""


def _load_pair(top: str, n_gate: int) -> str:
    return (
        _read_block(["gold_0.v"], top, "gold")
        + _read_block([f"gate_{i}.v" for i in range(n_gate)], top, "gate")
        + "design -copy-from gold -as gold gold\ndesign -copy-from gate -as gate gate\n"
    )


def _yosys(script: str, golden: Path, agent_files: list[Path], timeout: int, quiet: bool = True) -> tuple[int, str]:
    """Run a Yosys script in a scratch dir holding gold_0.v and gate_<i>.v (avoids path quoting issues)."""
    with tempfile.TemporaryDirectory(prefix="assay_eq_") as tmp:
        work = Path(tmp)
        shutil.copy(golden, work / "gold_0.v")
        for i, f in enumerate(agent_files):
            shutil.copy(f, work / f"gate_{i}.v")
        (work / "eq.ys").write_text(script, encoding="utf-8")
        return run_cmd(["yosys", *(["-q"] if quiet else []), "-s", "eq.ys"], work, timeout)


def equivalence(golden: Path, agent_files: list[Path], meta: dict) -> dict:
    """Formal equivalence of agent RTL vs golden.

    Returns {result: proven|failed|unknown|n/a, method, note}. 'unknown' is never treated as a pass.
    """
    mode = meta.get("equiv_mode", "none")
    top = meta.get("top", meta["module"])
    timeout = int(meta.get("equiv_timeout_s", 60))
    if mode == "none":
        return {"result": "n/a", "method": None, "note": "equivalence disabled for this task"}
    pair = _load_pair(top, len(agent_files))
    def run(script: str, quiet: bool = True) -> tuple[int, str]:
        return _yosys(script, golden, agent_files, timeout, quiet)

    if mode == "comb":
        script = pair + "miter -equiv -flatten -make_outputs gold gate miter\n" \
                        "hierarchy -top miter\nsat -verify -prove trigger 0 -show-inputs miter\n"
        code, out = run(script)
        if code == 0:
            return {"result": "proven", "method": "sat-comb", "note": ""}
        if code == -1:
            return {"result": "unknown", "method": "sat-comb", "note": "timeout"}
        if SAT_CEX_RE.search(out):
            return {"result": "failed", "method": "sat-comb", "note": tail(out, 1200)}
        return {"result": "unknown", "method": "sat-comb", "note": tail(out, 1200)}

    # Sequential: try an unbounded structural proof, then fall back to reset-anchored BMC.
    seq = int(meta.get("equiv_seq", 10))
    proof = pair + f"""equiv_make gold gate equiv
hierarchy -top equiv
async2sync
equiv_simple -seq {seq}
equiv_induct -seq {seq}
equiv_status -assert
"""
    code, out = run(proof)
    if code == 0:
        return {"result": "proven", "method": "equiv_induct", "note": ""}

    rst = meta.get("reset") or {}
    depth = int(meta.get("bmc_depth", 30))
    rst_at1 = f"-set-at 1 in_{rst['port']} {int(rst.get('active', 1))} " if rst else ""

    # k-induction proves designs whose state encoding differs from the golden (e.g. `!busy` vs
    # `state == IDLE`), which equiv_induct cannot match. It is only trusted to PROVE; a counterexample
    # verdict comes solely from the reset-anchored BMC below.
    kind = pair + f"""miter -equiv -flatten -make_outputs gold gate miter
hierarchy -top miter
async2sync
sat -tempinduct -prove trigger 0 {rst_at1}-set-init-zero -seq 1 -maxsteps {min(depth, KIND_MAX_STEPS)} miter
"""
    code, out = run(kind, quiet=False)
    if code == 0 and "Induction step proven: SUCCESS" in out:
        return {"result": "proven", "method": "k-induction", "note": ""}

    sets = f"{rst_at1}-prove-skip 1 " if rst else ""
    bmc = pair + f"""miter -equiv -flatten -make_outputs gold gate miter
hierarchy -top miter
async2sync
sat -verify -seq {depth} {sets}-set-init-zero -prove trigger 0 -show-inputs miter
"""
    code, out = run(bmc)
    if code == -1:
        return {"result": "unknown", "method": "bmc", "note": "timeout"}
    if code != 0 and SAT_CEX_RE.search(out):
        return {"result": "failed", "method": f"bmc-{depth}", "note": tail(out, 1500)}
    if code == 0:
        return {"result": "unknown", "method": f"bmc-{depth}",
                "note": f"no mismatch within {depth} cycles after reset; unbounded proof not reached"}
    return {"result": "unknown", "method": "bmc", "note": tail(out, 1200)}
