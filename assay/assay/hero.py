"""Render the single product screen (report/hero.html) from results/results.json.

Every number on the screen is read from results.json; nothing is typed in.
Usage: python -m assay.hero [--config v2]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .common import REPORT_DIR, RESULTS_DIR

TEMPLATE = Path(__file__).with_name("hero_template.html")
PLACEHOLDER = "/*__HERO_DATA__*/null"
DIFFICULTY_ORDER = {"easy": 0, "medium": 1, "hard": 2}


def _fail_line(run: dict) -> str:
    lines = [ln.strip() for ln in run["hidden_sim"]["output_tail"].splitlines() if ln.strip().startswith("FAIL")]
    if lines:
        return lines[0]
    if run["equiv"].get("result") == "failed":
        return "Formal equivalence: counterexample found against the reference design"
    return "Hidden testbench failed"


def pick_evidence(res: dict, cfg: str) -> dict | None:
    """A real wrong-but-finished run from the hero config with the clearest one-line claim."""
    cands = [r for r in res["runs"] if r["config"] == cfg
             and any(d["detector"] == "D1" for d in r["detections"])]
    if not cands:
        return None
    # Readable on a slide: short claim, short failure line, and the agent's own visible sim passed.
    cands.sort(key=lambda r: (len(r["claim_text"]) > 70, len(_fail_line(r)) > 90,
                              not any(s.get("sim_status") == "pass" for s in r["steps"]), r["run_id"]))
    r = cands[0]
    d1 = next(d for d in r["detections"] if d["detector"] == "D1")
    task = next(t for t in res["tasks"] if t["id"] == r["task"])
    passed_visible = any(s.get("sim_status") == "pass" for s in r["steps"])
    # The few steps that tell the story: reads, edits, sims (with outcome), and the flagged claim.
    trace = []
    for s in r["steps"]:
        if s["kind"] == "tool_call" and s.get("category") in ("read", "edit", "sim"):
            text = s["summary"].replace('cd "." && ', "").replace("cd . && ", "")
            trace.append({"i": s["i"], "cat": s["category"], "text": text})
        elif s["kind"] == "tool_result" and s.get("sim_status") in ("pass", "fail"):
            if trace and trace[-1]["cat"] == "sim":
                trace[-1]["sim"] = s["sim_status"]
    trace = trace[-4:] + [{"i": d1["step_index"], "cat": "claim", "text": r["claim_text"]}]
    return {"run_id": r["run_id"], "task": r["task"], "trial": r["trial"], "claim": r["claim_text"],
            "fail": _fail_line(r), "step": d1["step_index"], "n_steps": len(r["steps"]),
            "turns": r["turns"], "cost": r["cost_usd"], "bug": task.get("bug_description") or "",
            "passed_visible": passed_visible, "trace": trace}


def build(res: dict, cfg: str) -> dict:
    per = res["summary"]["per_config"]
    if cfg not in per:
        cfg = list(per)[-1]
    order = sorted(res["tasks"], key=lambda t: (DIFFICULTY_ORDER.get(t["difficulty"], 9), t["id"]))
    strip = []
    for t in order:
        for r in t["results"].get(cfg, {}).get("runs", []):
            strip.append({"task": t["id"], "difficulty": t["difficulty"], "verdict": r["verdict"],
                          "claimed": r["claimed_done"], "run_id": r["run_id"]})
    # Timing-diagram grid: one column per (task, trial), shared by every agent so columns line up.
    cfg_ids = [c["id"] for c in res["configs"]]
    columns = []
    for t in order:
        n = max((len(t["results"].get(c, {}).get("runs", [])) for c in cfg_ids), default=0)
        for k in range(max(n, res["trials"])):
            cell = {"task": t["id"], "difficulty": t["difficulty"], "trial": k + 1, "by": {}}
            for c in cfg_ids:
                rs = t["results"].get(c, {}).get("runs", [])
                r = next((x for x in rs if x["run_id"].endswith(f"__t{k + 1}")), None)
                cell["by"][c] = None if r is None else {"claimed": r["claimed_done"], "verdict": r["verdict"]}
            columns.append(cell)
    trust = [t["trust"]["trust"] for t in res["tasks"] if t.get("trust") and t["trust"].get("trust") is not None]
    missed = sum(t["visible_tb_weak"] for t in res["tasks"])
    issues = [{"id": i["detector"], "name": i["name"], "desc": i["description"], "count": i["count"],
               "by_config": i["by_config"]} for i in res["summary"]["issues"]]
    return {
        "generated_at": res["generated_at"],
        "hero": cfg,
        "configs": res["configs"],
        "per": per,
        "comparison": res["summary"]["comparison"],
        "totals": {"runs": res["summary"]["total_runs"], "tasks": res["summary"]["total_tasks"],
                   "cost": res["summary"]["total_cost_usd"], "trials": res["trials"],
                   "wbf": res["summary"]["wrong_but_finished"]},
        "strip": strip,
        "columns": columns,
        "evidence": pick_evidence(res, cfg),
        "issues": issues,
        "trust": {"mean": sum(trust) / len(trust) if trust else None, "tasks_missed": missed,
                  "tasks": len(res["tasks"])},
    }


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default="v2")
    args = ap.parse_args(argv)
    res = json.loads((RESULTS_DIR / "results.json").read_text(encoding="utf-8"))
    data = build(res, args.config)
    html = TEMPLATE.read_text(encoding="utf-8")
    payload = json.dumps(data, separators=(",", ":")).replace("</", "<\\/")
    out = REPORT_DIR / "hero.html"
    out.write_text(html.replace(PLACEHOLDER, payload), encoding="utf-8")
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
