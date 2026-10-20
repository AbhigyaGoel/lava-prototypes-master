"""Run Claude Code headless on every (config, task, trial). Parallel and resumable.

Usage:
  python -m assay.runner [--configs v1,v2] [--tasks a,b] [--trials 3] [--parallel 5] [--retry-crashed]
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from .common import AGENT_VISIBLE, RUNS_DIR, Task, eda_env, load_config, load_tasks, rm_tree

AGENT_TOOLS = "Read,Edit,Write,Bash,Glob,Grep"


def run_id_for(config_id: str, task_id: str, trial: int) -> str:
    return f"{config_id}__{task_id}__t{trial}"


def prepare_workspace(task: Task, run_dir: Path) -> Path:
    """Fresh copy of the agent-visible task files. hidden/ is never copied."""
    ws = run_dir / "workspace"
    orig = run_dir / "original"
    for d in (ws, orig):
        if d.exists():
            rm_tree(d)
        d.mkdir(parents=True)
        for name in AGENT_VISIBLE:
            src = task.dir / name
            if src.is_dir():
                shutil.copytree(src, d / name)
            elif src.is_file():
                shutil.copy(src, d / name)
    assert_no_hidden(task, ws)
    isolate_git(ws)
    return ws


def isolate_git(ws: Path) -> None:
    """Make the workspace its own git repo, so Claude Code's git context (status, recent commits)
    describes only this task and never the Assay repo around it (which lists tasks/*/hidden)."""
    git = ["git", "-c", "user.name=assay", "-c", "user.email=assay@localhost", "-c", "core.autocrlf=false"]
    for args in (["init", "-q"], ["add", "-A"], ["commit", "-q", "-m", "task"]):
        subprocess.run(git + args, cwd=ws, check=True, capture_output=True)


def assert_no_hidden(task: Task, ws: Path) -> None:
    """Guardrail: no hidden grader file (by name or by content) may exist in the agent workspace."""
    assert not (ws / "hidden").exists(), "hidden/ leaked into workspace"
    secret = {p.read_bytes() for p in (task.dir / "hidden").iterdir() if p.is_file()}
    for f in ws.rglob("*"):
        if f.is_file():
            assert f.name not in ("golden.v", "tb_hidden.v"), f"hidden file name in workspace: {f}"
            assert f.read_bytes() not in secret, f"hidden file content in workspace: {f}"


def build_prompt(cfg: dict, conf: dict) -> str:
    suffix = (conf.get("prompt_suffix") or "").strip()
    return cfg["base_prompt"].strip() + (("\n\n" + suffix) if suffix else "")


def claude_cmd(conf: dict, cfg: dict) -> list[str]:
    exe = shutil.which("claude")
    if not exe:
        raise SystemExit("claude CLI not found on PATH")
    # --safe-mode: no user CLAUDE.md/hooks/plugins/MCP leak into the agent; dontAsk + allowlist:
    # anything outside the six tools is denied without prompting. No --dangerously-skip-permissions.
    return [
        exe, "-p", "--output-format", "stream-json", "--verbose",
        "--model", conf["model"], "--max-turns", str(cfg["max_turns"]),
        "--tools", AGENT_TOOLS, "--allowedTools", AGENT_TOOLS,
        "--permission-mode", "dontAsk", "--safe-mode", "--strict-mcp-config",
        "--no-session-persistence",
    ]


def kill_tree(proc: subprocess.Popen) -> None:
    if sys.platform == "win32":
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)
    else:
        proc.kill()


def execute_run(task: Task, conf: dict, cfg: dict, trial: int) -> dict:
    rid = run_id_for(conf["id"], task.id, trial)
    run_dir = RUNS_DIR / rid
    run_dir.mkdir(parents=True, exist_ok=True)
    ws = prepare_workspace(task, run_dir)
    prompt = build_prompt(cfg, conf)
    cmd = claude_cmd(conf, cfg)
    timeout = int(cfg["timeout_s"])

    start = time.time()
    times: list[float] = []
    result_event = None
    timed_out = False
    with open(run_dir / "transcript.jsonl", "w", encoding="utf-8") as tf, \
         open(run_dir / "stderr.txt", "w", encoding="utf-8") as ef:
        proc = subprocess.Popen(
            cmd, cwd=ws, env=eda_env(), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=ef, text=True, encoding="utf-8", errors="replace",
        )
        timed_flag: list[bool] = []
        timer = threading.Timer(timeout, lambda: (_set(timed_flag), kill_tree(proc)))
        timer.start()
        try:
            proc.stdin.write(prompt)
            proc.stdin.close()
            for line in proc.stdout:
                if not line.strip():
                    continue
                times.append(round(time.time() - start, 3))
                tf.write(line if line.endswith("\n") else line + "\n")
                tf.flush()
                try:
                    ev = json.loads(line)
                    if ev.get("type") == "result":
                        result_event = ev
                except json.JSONDecodeError:
                    pass
            proc.wait()
        finally:
            timer.cancel()
        timed_out = bool(timed_flag)

    status = classify_status(result_event, timed_out, proc.returncode)
    if status == "crash" and is_rate_limited(result_event, run_dir):
        status = "rate_limited"
    meta = {
        "run_id": rid, "config": conf["id"], "model": conf["model"], "task": task.id, "trial": trial,
        "status": status, "exit_code": proc.returncode, "timed_out": timed_out,
        "duration_s": round(time.time() - start, 1),
        "cost_usd": (result_event or {}).get("total_cost_usd"),
        "turns": (result_event or {}).get("num_turns"),
        "result_subtype": (result_event or {}).get("subtype"),
        "final_text": (result_event or {}).get("result"),
        "prompt": prompt, "cmd": [Path(cmd[0]).name, *cmd[1:]],
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(start)),
        "complete": status != "rate_limited",  # rate-limited runs are retried on the next invocation
    }
    (run_dir / "timing.json").write_text(json.dumps(times), encoding="utf-8")
    (run_dir / "meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    return meta


def _set(flag: list) -> None:
    flag.append(True)


def classify_status(result_event: dict | None, timed_out: bool, exit_code: int | None) -> str:
    if timed_out:
        return "timeout"
    if not result_event:
        return "crash"
    sub = result_event.get("subtype", "")
    if sub == "success" and not result_event.get("is_error"):
        return "finished"
    if "max_turns" in sub:
        return "max_turns"
    return "crash"


LIMIT_WORDS = ("rate limit", "usage limit", "session limit", "limit reached", "overloaded", "hit your")


def is_rate_limited(result_event: dict | None, run_dir: Path) -> bool:
    if (result_event or {}).get("api_error_status") in (429, 529):
        return True
    text = str((result_event or {}).get("result", "")).lower()
    err = (run_dir / "stderr.txt").read_text(encoding="utf-8", errors="replace").lower()
    return any(w in text or w in err for w in LIMIT_WORDS)


def load_meta(rid: str) -> dict | None:
    p = RUNS_DIR / rid / "meta.json"
    if not p.is_file():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--configs")
    ap.add_argument("--tasks")
    ap.add_argument("--trials", type=int)
    ap.add_argument("--parallel", type=int)
    ap.add_argument("--retry-crashed", action="store_true")
    args = ap.parse_args(argv)

    cfg = load_config()
    confs = [c for c in cfg["configs"] if not args.configs or c["id"] in args.configs.split(",")]
    tasks = load_tasks(args.tasks.split(",") if args.tasks else None)
    trials = args.trials or cfg["trials"]
    parallel = args.parallel or cfg["parallelism"]
    budget = float(cfg["budget_usd"])

    spent = sum((m.get("cost_usd") or 0) for d in RUNS_DIR.glob("*") if (m := load_meta(d.name)))
    todo = []
    for t in range(1, trials + 1):  # trial-major order: every task gets trial 1 before any trial 2
        for task in tasks:
            for conf in confs:
                m = load_meta(run_id_for(conf["id"], task.id, t))
                if m and m.get("complete") and not (args.retry_crashed and m["status"] == "crash"):
                    continue
                todo.append((task, conf, t))
    print(f"{len(todo)} runs to do; ${spent:.2f} already spent; budget ${budget:.0f}; parallel={parallel}")

    lock = threading.Lock()
    stop = threading.Event()

    def job(task: Task, conf: dict, t: int) -> dict | None:
        nonlocal spent
        if stop.is_set():
            return None
        meta = execute_run(task, conf, cfg, t)
        with lock:
            spent += meta.get("cost_usd") or 0
            if spent > budget:
                stop.set()
            if meta["status"] == "rate_limited":
                stop.set()
                print("  RATE LIMITED: stopping; rerun later to resume", flush=True)
            print(f"  {meta['run_id']:40s} {meta['status']:9s} turns={meta['turns']} "
                  f"${meta['cost_usd'] or 0:.3f} {meta['duration_s']}s  total=${spent:.2f}", flush=True)
        return meta

    with ThreadPoolExecutor(max_workers=parallel) as pool:
        futs = [pool.submit(job, *x) for x in todo]
        for f in as_completed(futs):
            exc = f.exception()
            if exc:
                print(f"  run raised: {exc!r}", flush=True)
    if stop.is_set():
        print(f"STOPPED: budget ${budget:.0f} exceeded (spent ${spent:.2f})")
        return 3
    print(f"done. total spent ${spent:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
