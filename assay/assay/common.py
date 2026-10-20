"""Shared paths, config loading and EDA tool helpers."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
TASKS_DIR = ROOT / "tasks"
# Overridable so `make demo` can write somewhere that never touches the precomputed report.
RUNS_DIR = Path(os.environ.get("ASSAY_RUNS_DIR", ROOT / "runs"))
RESULTS_DIR = Path(os.environ.get("ASSAY_RESULTS_DIR", ROOT / "results"))
REPORT_DIR = Path(os.environ.get("ASSAY_REPORT_DIR", ROOT / "report"))
CONFIG_PATH = ROOT / "configs.yaml"

# Markers every testbench in the suite prints (see tasks/README.md).
PASS_MARKER = "TEST PASSED"
SIM_TIMEOUT_S = 60

# Files the agent is allowed to see. hidden/ is never copied.
AGENT_VISIBLE = ("spec.md", "rtl", "tb")


@dataclass(frozen=True)
class Task:
    id: str
    dir: Path
    meta: dict

    @property
    def module(self) -> str:
        return self.meta["module"]

    @property
    def top(self) -> str:
        return self.meta.get("top", self.meta["module"])

    @property
    def golden(self) -> Path:
        return self.dir / "hidden" / "golden.v"

    @property
    def tb_hidden(self) -> Path:
        return self.dir / "hidden" / "tb_hidden.v"

    @property
    def tb_visible(self) -> Path:
        return self.dir / "tb" / "tb_visible.v"

    @property
    def files_in_scope(self) -> list[str]:
        return self.meta.get("files_in_scope", [f"rtl/{self.module}.v"])


def load_config() -> dict:
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_tasks(only: list[str] | None = None) -> list[Task]:
    tasks = []
    for d in sorted(TASKS_DIR.iterdir()):
        meta_path = d / "task.json"
        if not meta_path.is_file():
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if only and meta["id"] not in only:
            continue
        tasks.append(Task(id=meta["id"], dir=d, meta=meta))
    return tasks


def eda_env() -> dict:
    """Environment with iverilog/vvp/yosys on PATH (configurable via configs.yaml or ASSAY_EDA_BIN)."""
    env = dict(os.environ)
    eda_bin = os.environ.get("ASSAY_EDA_BIN")
    if not eda_bin and CONFIG_PATH.exists():
        eda_bin = (load_config().get("eda_bin") or "").strip()
    if eda_bin:
        b = Path(os.path.expanduser(eda_bin))
        extra = [str(b), str(b.parent / "lib")]
        env["PATH"] = os.pathsep.join(extra + [env.get("PATH", "")])
    return env


def which(tool: str) -> str | None:
    return shutil.which(tool, path=eda_env()["PATH"])


def run_cmd(args: list[str], cwd: Path, timeout: int = SIM_TIMEOUT_S) -> tuple[int, str]:
    """Run a command, returning (exit_code, combined_output). Exit code -1 means timeout."""
    exe = which(args[0]) or args[0]
    try:
        p = subprocess.run(
            [exe, *args[1:]], cwd=cwd, env=eda_env(), capture_output=True, text=True,
            timeout=timeout, encoding="utf-8", errors="replace",
        )
        return p.returncode, (p.stdout or "") + (p.stderr or "")
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"")
        out = out.decode("utf-8", "replace") if isinstance(out, bytes) else out
        return -1, out + "\n[assay] TIMEOUT"


def rm_tree(path: Path) -> None:
    """shutil.rmtree that also removes read-only files (git objects on Windows)."""
    import stat

    def _force(func, target, _exc):
        os.chmod(target, stat.S_IWRITE)
        func(target)

    shutil.rmtree(path, onerror=_force)


def tail(text: str, n_chars: int = 2000) -> str:
    return text if len(text) <= n_chars else "..." + text[-n_chars:]
