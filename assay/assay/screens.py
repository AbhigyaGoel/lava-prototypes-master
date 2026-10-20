"""Capture 1440px-wide screenshots of the report with headless Chrome/Edge -> report/screens/.

Usage: python -m assay.screens [view ...]    views like: overview issues tasks runs run/<run_id>/<step>
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from .common import REPORT_DIR, RESULTS_DIR

BROWSERS = [
    "chrome", "msedge", "google-chrome", "chromium",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
]


def find_browser() -> str | None:
    for b in BROWSERS:
        p = shutil.which(b) or (b if Path(b).is_file() else None)
        if p:
            return p
    return None


def shoot(browser: str, view: str, out: Path, height: int, theme: str = "light") -> None:
    if view == "hero":  # the single product screen (light only, by design)
        url = (REPORT_DIR / "hero.html").resolve().as_uri()
    else:
        url = (REPORT_DIR / "index.html").resolve().as_uri() + f"?theme={theme}&noscroll=1#/{view}"
    subprocess.run([browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--window-size=1440,{height}",
                    "--force-device-scale-factor=2", f"--screenshot={out}", "--virtual-time-budget=3000", url],
                   capture_output=True, timeout=60)


def default_views() -> list[tuple[str, str, int]]:
    views = [("hero", "hero", 960), ("overview", "overview", 1500), ("issues", "issues", 1700), ("tasks", "tasks", 1500)]
    res = json.loads((RESULTS_DIR / "results.json").read_text(encoding="utf-8"))
    issues = res["summary"]["issues"]
    if issues:
        ex = issues[0]["example"]
        views.append((f"run/{ex['run_id']}/{ex['step_index']}", "run_flagged", 3000))
    return views


def main(argv: list[str]) -> int:
    browser = find_browser()
    if not browser:
        print("No Chrome/Edge found; skipping screenshots.")
        return 1
    out_dir = REPORT_DIR / "screens"
    out_dir.mkdir(parents=True, exist_ok=True)
    views = [(v, v.replace("/", "_"), 1500) for v in argv] if argv else default_views()
    for view, name, h in views:
        for theme in ("light", "dark"):
            if view == "hero" and theme == "dark":
                continue
            out = out_dir / f"{name}{'' if theme == 'light' else '_dark'}.png"
            shoot(browser, view, out, h, theme)
            print(f"  {out.relative_to(REPORT_DIR.parent)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
