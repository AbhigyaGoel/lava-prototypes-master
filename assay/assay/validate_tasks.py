"""Sanity-check every task: golden passes both TBs, buggy fails hidden, equivalence harness works.

Usage: python -m assay.validate_tasks [task_id ...]
"""
from __future__ import annotations

import sys

from .common import Task, load_tasks, which
from .eda import equivalence, simulate


def rtl_files(task: Task) -> list:
    return sorted((task.dir / "rtl").glob("*.v"))


def validate(task: Task) -> tuple[list[str], list[str]]:
    """Returns (errors, warnings)."""
    errors, warnings = [], []
    for rel in ("spec.md", "tb/tb_visible.v", "hidden/golden.v", "hidden/tb_hidden.v"):
        if not (task.dir / rel).is_file():
            errors.append(f"missing {rel}")
    for rel in task.files_in_scope:
        if not (task.dir / rel).is_file():
            errors.append(f"files_in_scope entry missing: {rel}")
    if errors:
        return errors, warnings

    buggy = rtl_files(task)
    golden_hidden = simulate(task.tb_hidden, [task.golden])
    if not golden_hidden["passed"]:
        errors.append(f"golden FAILS tb_hidden: {golden_hidden['output_tail'][-400:]}")
    golden_visible = simulate(task.tb_visible, [task.golden])
    if not golden_visible["passed"]:
        errors.append(f"golden FAILS tb_visible: {golden_visible['output_tail'][-400:]}")
    buggy_hidden = simulate(task.tb_hidden, buggy)
    if buggy_hidden["passed"]:
        errors.append("buggy RTL PASSES tb_hidden (hidden test does not catch the bug)")

    if task.meta.get("equiv_mode", "none") != "none":
        self_eq = equivalence(task.golden, [task.golden], task.meta)
        if self_eq["result"] != "proven":
            errors.append(f"golden-vs-golden equivalence not proven: {self_eq}")
        bug_eq = equivalence(task.golden, buggy, task.meta)
        if bug_eq["result"] != "failed":
            warnings.append(f"golden-vs-buggy equivalence = {bug_eq['result']} (expected failed)")

    buggy_visible = simulate(task.tb_visible, buggy)
    weak = bool(task.meta.get("visible_tb_weak"))
    if weak and not buggy_visible["passed"]:
        warnings.append("visible_tb_weak=true but visible TB already catches the bug")
    if not weak and buggy_visible["passed"]:
        warnings.append("visible_tb_weak=false but buggy RTL passes the visible TB")
    return errors, warnings


def main(argv: list[str]) -> int:
    for tool in ("iverilog", "vvp", "yosys"):
        if not which(tool):
            print(f"ERROR: {tool} not found. Set eda_bin in configs.yaml or ASSAY_EDA_BIN.")
            return 2
    tasks = load_tasks(argv or None)
    if not tasks:
        print("No tasks found.")
        return 2
    failed = 0
    for t in tasks:
        errs, warns = validate(t)
        status = "FAIL" if errs else "ok  "
        print(f"[{status}] {t.id:24s} {t.meta.get('difficulty', '?'):6s} {t.meta.get('bug_type', '')}")
        for e in errs:
            print(f"        error: {e}")
        for w in warns:
            print(f"        warn:  {w}")
        failed += bool(errs)
    print(f"\n{len(tasks) - failed}/{len(tasks)} tasks valid")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
