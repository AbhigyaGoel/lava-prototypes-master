"""Grader trust score: what fraction of real bugs does each task's *visible* testbench catch?

Mutants of the golden RTL are generated with simple operator/constant mutations. A mutant counts as a
real bug if the strong hidden testbench kills it; the trust score is the share of those the visible TB kills.

Usage: python -m assay.trust [task_id ...]   -> results/trust.json
"""
from __future__ import annotations

import json
import random
import re
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from .common import RESULTS_DIR, Task, load_tasks
from .eda import simulate

MAX_MUTANTS = 40
SEED = 7

# (name, pattern, replacement). Patterns avoid the non-blocking assignment `<=`.
OPERATORS = [
    ("eq->neq", re.compile(r"=="), "!="),
    ("neq->eq", re.compile(r"!="), "=="),
    ("lt->le", re.compile(r"(?<=[\w)\]] )<(?=[ (\w])"), "<="),
    ("gt->ge", re.compile(r"(?<=[\w)\]] )>(?=[ (\w])"), ">="),
    ("ge->gt", re.compile(r">="), ">"),
    ("and->or", re.compile(r"&&"), "||"),
    ("or->and", re.compile(r"\|\|"), "&&"),
    ("bitand->bitor", re.compile(r"(?<![&\w])&(?![&])(?=\s*[\w(~])"), "|"),
    ("plus->minus", re.compile(r"(?<=[\w)\]] )\+(?= )"), "-"),
    ("minus->plus", re.compile(r"(?<=[\w)\]] )-(?= )"), "+"),
    ("drop-not", re.compile(r"!(?=[\w(])"), ""),
    ("bit0->1", re.compile(r"1'b0"), "1'b1"),
    ("bit1->0", re.compile(r"1'b1"), "1'b0"),
]
CONST_RE = re.compile(r"(\d+)'d(\d+)")
BIN_RE = re.compile(r"(\d+)'([bBhH])([0-9a-fA-F_]+)")


def _strip_comments(text: str) -> list[tuple[int, int]]:
    """Spans of comments, so mutations never land inside them."""
    return [m.span() for m in re.finditer(r"//[^\n]*|/\*.*?\*/", text, re.S)]


def mutants(src: str) -> list[tuple[str, str]]:
    comments = _strip_comments(src)
    in_comment = lambda i: any(a <= i < b for a, b in comments)  # noqa: E731
    out = []
    for name, pat, rep in OPERATORS:
        for m in pat.finditer(src):
            if not in_comment(m.start()):
                out.append((f"{name}@{m.start()}", src[:m.start()] + rep + src[m.end():]))
    for m in CONST_RE.finditer(src):
        if in_comment(m.start()):
            continue
        width, val = int(m.group(1)), int(m.group(2))
        for delta in (-1, 1):
            nv = val + delta
            if 0 <= nv < 2 ** width:
                out.append((f"const{delta:+d}@{m.start()}", src[:m.start()] + f"{width}'d{nv}" + src[m.end():]))
    rng = random.Random(SEED)
    for m in BIN_RE.finditer(src):  # flip one bit of multi-bit binary/hex literals (tables, masks)
        if in_comment(m.start()):
            continue
        width, base, digits = int(m.group(1)), m.group(2).lower(), m.group(3).replace("_", "")
        try:
            val = int(digits, 2 if base == "b" else 16)
        except ValueError:
            continue  # x/z digits
        nv = val ^ (1 << rng.randrange(width))
        lit = f"{width}'b{nv:0{width}b}" if base == "b" else f"{width}'h{nv:x}"
        out.append((f"flip@{m.start()}", src[:m.start()] + lit + src[m.end():]))
    rng.shuffle(out)
    return out[:MAX_MUTANTS]


def score_task(task: Task) -> dict:
    src = task.golden.read_text(encoding="utf-8")
    results = []
    with tempfile.TemporaryDirectory(prefix="assay_mut_") as tmp:
        for name, text in mutants(src):
            f = Path(tmp) / f"{task.module}.v"
            f.write_text(text, encoding="utf-8")
            hidden = simulate(task.tb_hidden, [f])
            if hidden["passed"] or hidden["reason"] == "compile_error":
                continue  # equivalent or invalid mutant: not a real bug
            visible = simulate(task.tb_visible, [f])
            results.append({"mutant": name, "visible_kills": not visible["passed"]})
    killed = sum(r["visible_kills"] for r in results)
    return {"task": task.id, "real_bugs": len(results), "visible_catches": killed,
            "trust": killed / len(results) if results else None,
            "missed": [r["mutant"] for r in results if not r["visible_kills"]]}


def main(argv: list[str]) -> int:
    tasks = load_tasks(argv or None)
    with ThreadPoolExecutor(max_workers=6) as pool:
        scores = list(pool.map(score_task, tasks))
    for s in scores:
        t = "–" if s["trust"] is None else f"{s['trust']:.0%}"
        print(f"  {s['task']:20s} visible TB catches {s['visible_catches']:2d}/{s['real_bugs']:2d} real bugs ({t})")
    out = RESULTS_DIR / "trust.json"
    existing = json.loads(out.read_text(encoding="utf-8")) if out.is_file() and argv else {}
    existing.update({s["task"]: s for s in scores})
    RESULTS_DIR.mkdir(exist_ok=True)
    out.write_text(json.dumps(existing, indent=1), encoding="utf-8")
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
