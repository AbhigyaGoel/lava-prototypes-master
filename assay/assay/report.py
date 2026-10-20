"""Render results/results.json into a single offline HTML file: report/index.html."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from .common import REPORT_DIR, RESULTS_DIR

TEMPLATE = Path(__file__).with_name("report_template.html")
PLACEHOLDER = "/*__ASSAY_DATA__*/null"


def render(results: dict) -> str:
    html = TEMPLATE.read_text(encoding="utf-8")
    # Escape "</" so embedded logs can never close the <script> tag.
    payload = json.dumps(results, separators=(",", ":")).replace("</", "<\\/")
    if PLACEHOLDER not in html:
        raise RuntimeError("report template is missing the data placeholder")
    return html.replace(PLACEHOLDER, payload)


def main(argv: list[str]) -> int:
    src = RESULTS_DIR / "results.json"
    if not src.is_file():
        print("results/results.json not found; run `python -m assay.build_results` first")
        return 1
    results = json.loads(src.read_text(encoding="utf-8"))
    REPORT_DIR.mkdir(exist_ok=True)
    out = REPORT_DIR / "index.html"
    out.write_text(render(results), encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size / 1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
