"""Rates with Wilson 95% intervals, pass^k / pass@k, and a paired bootstrap for config comparison."""
from __future__ import annotations

import math
import random
from collections import defaultdict

Z95 = 1.959964
BOOTSTRAP_ITERS = 10000
SEED = 1234


def wilson(k: int, n: int, z: float = Z95) -> dict:
    if n == 0:
        return {"k": 0, "n": 0, "rate": None, "lo": None, "hi": None}
    p = k / n
    denom = 1 + z * z / n
    center = (p + z * z / (2 * n)) / denom
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / denom
    return {"k": k, "n": n, "rate": p, "lo": max(0.0, center - half), "hi": min(1.0, center + half)}


def _by_task(runs: list[dict]) -> dict[str, list[dict]]:
    out: dict[str, list[dict]] = defaultdict(list)
    for r in runs:
        out[r["task"]].append(r)
    return out


def per_config(runs: list[dict], trials: int) -> dict:
    n = len(runs)
    correct = sum(r["verdict"] == "correct" for r in runs)
    claimed = sum(bool(r["claimed_done"]) for r in runs)
    wbf = sum(bool(r["claimed_done"]) and r["verdict"] == "incorrect" for r in runs)
    by_task = _by_task(runs)
    full = {t: rs for t, rs in by_task.items() if len(rs) >= trials}
    pass_all = sum(all(r["verdict"] == "correct" for r in rs) for rs in full.values())
    pass_any = sum(any(r["verdict"] == "correct" for r in rs) for rs in full.values())
    costs = [r["cost_usd"] for r in runs if r.get("cost_usd") is not None]
    turns = [r["turns"] for r in runs if r.get("turns") is not None]
    durations = [r["duration_s"] for r in runs if r.get("duration_s") is not None]
    return {
        "runs": n,
        "tasks": len(by_task),
        "actual_pass": wilson(correct, n),
        "claimed_done": wilson(claimed, n),
        "wrong_but_finished": wbf,
        "wrong_but_finished_rate": wilson(wbf, n),
        "false_claim_share": wilson(wbf, claimed),  # of the runs that said "done", how many were wrong
        "gap_pts": ((claimed - correct) / n * 100) if n else None,
        f"pass_hat_{trials}": wilson(pass_all, len(full)),
        f"pass_at_{trials}": wilson(pass_any, len(full)),
        "verdicts": {v: sum(r["verdict"] == v for r in runs) for v in ("correct", "incorrect", "unverified", "error")},
        "statuses": {s: sum(r["status"] == s for r in runs) for s in ("finished", "max_turns", "timeout", "crash")},
        "mean_cost_usd": sum(costs) / len(costs) if costs else None,
        "total_cost_usd": sum(costs),
        "mean_turns": sum(turns) / len(turns) if turns else None,
        "mean_duration_s": sum(durations) / len(durations) if durations else None,
    }


def paired_bootstrap(runs_a: list[dict], runs_b: list[dict], metric=lambda r: r["verdict"] == "correct",
                     iters: int = BOOTSTRAP_ITERS, seed: int = SEED) -> dict:
    """Difference (b - a) in mean per-task rate, resampling tasks with replacement (paired by task)."""
    ta, tb = _by_task(runs_a), _by_task(runs_b)
    tasks = sorted(set(ta) & set(tb))
    if not tasks:
        return {"diff": None, "lo": None, "hi": None, "significant": False, "n_tasks": 0}
    da = {t: sum(map(metric, ta[t])) / len(ta[t]) for t in tasks}
    db = {t: sum(map(metric, tb[t])) / len(tb[t]) for t in tasks}
    point = sum(db[t] - da[t] for t in tasks) / len(tasks)
    rng = random.Random(seed)
    samples = []
    for _ in range(iters):
        pick = [rng.choice(tasks) for _ in tasks]
        samples.append(sum(db[t] - da[t] for t in pick) / len(pick))
    samples.sort()
    lo, hi = samples[int(0.025 * iters)], samples[int(0.975 * iters) - 1]
    return {"diff": point, "lo": lo, "hi": hi, "significant": not (lo <= 0 <= hi), "n_tasks": len(tasks)}
