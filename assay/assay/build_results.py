"""Assemble runs/ into results/results.json: normalized steps, grades, detections, statistics, issues."""
from __future__ import annotations

import json
import sys
import time
from collections import defaultdict
from pathlib import Path

from .common import RESULTS_DIR, RUNS_DIR, load_config, load_tasks
from .detect import DETECTORS, run_detectors
from .grade import grade_run
from .normalize import normalize, public_step
from .stats import paired_bootstrap, per_config, wilson

SEVERITY_ORDER = {"high": 0, "medium": 1, "low": 2}


def build_run(run_dir: Path, task) -> dict:
    meta = json.loads((run_dir / "meta.json").read_text(encoding="utf-8"))
    grade_path = run_dir / "grade.json"
    grade = json.loads(grade_path.read_text(encoding="utf-8")) if grade_path.is_file() else grade_run(run_dir, task)
    timing = json.loads((run_dir / "timing.json").read_text(encoding="utf-8"))
    ws = run_dir / "workspace"
    steps, _ = normalize(run_dir / "transcript.jsonl", timing, ws)
    original_files = [p.relative_to(run_dir / "original").as_posix()
                      for p in (run_dir / "original").rglob("*") if p.is_file()]
    detections = run_detectors(steps, grade, task.files_in_scope, original_files)
    for d in detections:
        if d["step_index"] is not None and 0 <= d["step_index"] < len(steps):
            steps[d["step_index"]]["flag"] = (steps[d["step_index"]]["flag"] or []) + [d["detector"]]
    return {
        "run_id": meta["run_id"], "config": meta["config"], "model": meta["model"],
        "task": meta["task"], "trial": meta["trial"], "status": meta["status"],
        "claimed_done": grade["claimed_done"], "claim_text": grade["claim_text"],
        "final_text": (meta.get("final_text") or "")[:4000],
        "verdict": grade["verdict"],
        "hidden_sim": {"passed": grade["hidden_sim"]["passed"], "reason": grade["hidden_sim"].get("reason"),
                       "output_tail": grade["hidden_sim"]["output_tail"]},
        "equiv": grade["equiv"],
        "cost_usd": meta.get("cost_usd"), "turns": meta.get("turns"), "duration_s": meta.get("duration_s"),
        "started_at": meta.get("started_at"),
        "files_changed": [c["path"] for c in grade["files_changed"]],
        "file_changes": grade["files_changed"],
        "diff": grade["diff"][:20000],
        "detections": detections,
        "steps": [public_step(s) for s in steps],
    }


def build_issues(runs: list[dict], config_ids: list[str]) -> list[dict]:
    groups: dict[str, list[dict]] = defaultdict(list)
    for r in runs:
        for d in r["detections"]:
            groups[d["detector"]].append({"run_id": r["run_id"], "config": r["config"], "task": r["task"],
                                          "step_index": d["step_index"], "severity": d["severity"],
                                          "evidence": d["evidence"]})
    issues = []
    for did, items in groups.items():
        info = DETECTORS[did]
        by_cfg = {c: sum(1 for it in items if it["config"] == c) for c in config_ids}
        runs_per_cfg = {c: sum(1 for r in runs if r["config"] == c) for c in config_ids}
        example = sorted(items, key=lambda it: (SEVERITY_ORDER[it["severity"]], it["config"] != config_ids[-1]))[0]
        issues.append({
            "detector": did, "name": info["name"], "description": info["description"],
            "severity": info["severity"], "count": len(items), "by_config": by_cfg,
            "rate_by_config": {c: wilson(by_cfg[c], runs_per_cfg[c]) for c in config_ids},
            "tasks": sorted({it["task"] for it in items}),
            "example": example, "runs": items,
        })
    issues.sort(key=lambda i: (-i["count"], SEVERITY_ORDER[i["severity"]]))
    return issues


def load_trust() -> dict:
    p = RESULTS_DIR / "trust.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.is_file() else {}


def task_table(tasks, runs: list[dict], config_ids: list[str]) -> list[dict]:
    trust = load_trust()
    out = []
    for t in tasks:
        row = {"id": t.id, "module": t.module, "difficulty": t.meta.get("difficulty"),
               "bug_type": t.meta.get("bug_type"), "bug_description": t.meta.get("bug_description"),
               "visible_tb_weak": bool(t.meta.get("visible_tb_weak")), "equiv_mode": t.meta.get("equiv_mode"),
               "trust": trust.get(t.id), "results": {}}
        for c in config_ids:
            rs = sorted((r for r in runs if r["task"] == t.id and r["config"] == c), key=lambda r: r["trial"])
            row["results"][c] = {
                "correct": sum(r["verdict"] == "correct" for r in rs),
                "claimed": sum(r["claimed_done"] for r in rs), "n": len(rs),
                "runs": [{"run_id": r["run_id"], "verdict": r["verdict"], "claimed_done": r["claimed_done"]} for r in rs],
            }
        out.append(row)
    return out


def main(argv: list[str]) -> int:
    cfg = load_config()
    tasks = load_tasks()
    task_by_id = {t.id: t for t in tasks}
    runs = []
    for run_dir in sorted(RUNS_DIR.iterdir()) if RUNS_DIR.exists() else []:
        meta_p = run_dir / "meta.json"
        if not meta_p.is_file():
            continue
        meta = json.loads(meta_p.read_text(encoding="utf-8"))
        if meta["task"] not in task_by_id or not meta.get("complete"):
            continue
        runs.append(build_run(run_dir, task_by_id[meta["task"]]))
    config_ids = [c["id"] for c in cfg["configs"] if any(r["config"] == c["id"] for r in runs)]
    trials = cfg["trials"]
    per = {c: per_config([r for r in runs if r["config"] == c], trials) for c in config_ids}
    comparison = []
    for a, b in zip(config_ids, config_ids[1:]):
        ra = [r for r in runs if r["config"] == a]
        rb = [r for r in runs if r["config"] == b]
        comparison.append({
            "a": a, "b": b,
            "actual_pass": paired_bootstrap(ra, rb),
            "claimed_done": paired_bootstrap(ra, rb, metric=lambda r: bool(r["claimed_done"])),
            "wrong_but_finished": paired_bootstrap(
                ra, rb, metric=lambda r: bool(r["claimed_done"]) and r["verdict"] == "incorrect"),
        })
    used_tasks = [t for t in tasks if any(r["task"] == t.id for r in runs)]
    results = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "configs": [{"id": c["id"], "label": c.get("label", c["id"]), "model": c["model"],
                     "prompt_suffix": c.get("prompt_suffix", "")} for c in cfg["configs"] if c["id"] in config_ids],
        "base_prompt": cfg["base_prompt"],
        "trials": trials,
        "detectors": DETECTORS,
        "tasks": task_table(used_tasks, runs, config_ids),
        "runs": runs,
        "summary": {
            "total_runs": len(runs), "total_tasks": len(used_tasks),
            "total_cost_usd": sum(r["cost_usd"] or 0 for r in runs),
            "wrong_but_finished": sum(r["claimed_done"] and r["verdict"] == "incorrect" for r in runs),
            "per_config": per, "comparison": comparison,
            "issues": build_issues(runs, config_ids),
        },
    }
    RESULTS_DIR.mkdir(exist_ok=True)
    out = RESULTS_DIR / "results.json"
    out.write_text(json.dumps(results, indent=1), encoding="utf-8")
    print(f"wrote {out} ({len(runs)} runs, {len(used_tasks)} tasks, ${results['summary']['total_cost_usd']:.2f})")
    for c in config_ids:
        p = per[c]
        print(f"  {c}: claimed {p['claimed_done']['rate']:.0%}  actual {p['actual_pass']['rate']:.0%}  "
              f"wrong-but-finished {p['wrong_but_finished']}/{p['runs']}")
    for i in results["summary"]["issues"][:5]:
        print(f"  issue {i['detector']} {i['name']}: {i['count']} {i['by_config']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
