"""One-command entry point (works without make):

  python -m assay validate | trust | run | grade | results | report | screens | all | demo
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys

from .common import ROOT

STEPS = {
    "validate": ["assay.validate_tasks"],
    "run": ["assay.runner"],
    "grade": ["assay.grade"],
    "results": ["assay.build_results"],
    "report": ["assay.build_results", "assay.report", "assay.hero"],
    "screens": ["assay.screens"],
    "trust": ["assay.trust"],
}
STEPS["all"] = STEPS["validate"] + STEPS["trust"] + STEPS["run"] + STEPS["grade"] + STEPS["report"]
DEMO_TASKS = "gray_counter,priority_encoder"


def sh(module: str, args: list[str], env: dict | None = None) -> int:
    print(f"\n== python -m {module} {' '.join(args)}", flush=True)
    return subprocess.call([sys.executable, "-m", module, *args], cwd=ROOT, env=env)


def demo() -> int:
    """Fresh live run: 2 tasks x 1 config x 1 trial into demo/ (the precomputed report is untouched)."""
    d = ROOT / "demo"
    shutil.rmtree(d, ignore_errors=True)
    env = dict(os.environ, ASSAY_RUNS_DIR=str(d / "runs"), ASSAY_RESULTS_DIR=str(d / "results"),
               ASSAY_REPORT_DIR=str(d / "report"))
    for mod, args in (("assay.runner", ["--configs", "v2", "--tasks", DEMO_TASKS, "--trials", "1"]),
                      ("assay.grade", []), ("assay.build_results", []), ("assay.report", [])):
        if sh(mod, args, env) not in (0,):
            return 1
    print(f"\nDemo report: {d / 'report' / 'index.html'}")
    return 0


def main(argv: list[str]) -> int:
    cmd = argv[0] if argv else "report"
    if cmd == "demo":
        return demo()
    if cmd not in STEPS:
        print(__doc__)
        return 2
    for mod in STEPS[cmd]:
        code = sh(mod, argv[1:] if len(STEPS[cmd]) == 1 else [])
        if code != 0 and not (mod == "assay.runner" and code == 3):
            return code
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
