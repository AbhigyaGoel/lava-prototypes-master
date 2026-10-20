"""Normalize a Claude Code stream-json transcript into a flat list of timeline steps."""
from __future__ import annotations

import json
import re
from pathlib import Path

from .eda import classify_sim_output

DETAIL_MAX = 4096
SUMMARY_MAX = 180

SIM_RE = re.compile(r"\bvvp\b")
LINE_NO_RE = re.compile(r"^ *\d+\t", re.MULTILINE)
READ_CMD_RE = re.compile(r"\b(cat|head|tail|less|more|type|grep|sed\s+-n|awk|nl)\b")
# Heuristic shell-write targets; the workspace diff remains the source of truth.
WRITE_PATTERNS = [
    re.compile(r"\bsed\s+(?:-\w+\s+)*-i\S*\s+.*?([\w./\\-]+\.(?:v|sv|md))\b"),
    re.compile(r"(?<![0-9&])>{1,2}\s*([\w./\\-]+\.(?:v|sv|md))"),
    re.compile(r"\btee\s+(?:-a\s+)?([\w./\\-]+\.(?:v|sv|md))"),
    re.compile(r"\b(?:cp|mv)\s+(?:-\w+\s+)*\S+\s+([\w./\\-]+\.(?:v|sv|md))"),
    re.compile(r"\brm\s+(?:-\w+\s+)*([\w./\\-]+\.(?:v|sv|md))"),
]


def rel_path(p: str, ws: Path) -> str:
    """Workspace-relative POSIX path if p is inside the workspace, else the original string."""
    if not p:
        return p
    norm = p.replace("\\", "/")
    ws_norm = str(ws).replace("\\", "/")
    low, wlow = norm.lower().rstrip("/"), ws_norm.lower()
    if low == wlow:
        return "."
    if low.startswith(wlow + "/"):
        return norm[len(ws_norm) + 1:]
    # Git-bash style /c/Users/... form
    if len(wlow) > 2 and wlow[1] == ":":
        alt = "/" + wlow[0] + wlow[2:]
        if low.startswith(alt + "/"):
            return norm[len(alt) + 1:]
    return norm


def strip_ws(text: str, ws: Path) -> str:
    """Remove absolute workspace prefixes from free text (commands, outputs) for readability."""
    w = str(ws)
    for form in (w, w.replace("\\", "/"), "/" + w[0].lower() + w[2:].replace("\\", "/")):
        text = re.sub(re.escape(form) + r"[\\/]", "", text, flags=re.IGNORECASE)
        text = re.sub(re.escape(form), ".", text, flags=re.IGNORECASE)
    return text


def bash_write_targets(cmd: str) -> list[str]:
    out = []
    for pat in WRITE_PATTERNS:
        out += [m.group(1).replace("\\", "/").lstrip("./") for m in pat.finditer(cmd)]
    return sorted(set(out))


def _result_text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(c.get("text", "") for c in content if isinstance(c, dict))
    return str(content)


def _clip(s: str, n: int) -> str:
    s = s.strip()
    return s if len(s) <= n else s[: n - 1] + "…"


def _call_step(block: dict, ws: Path) -> dict:
    name = block.get("name", "")
    inp = block.get("input") or {}
    step = {"kind": "tool_call", "tool": name, "call_id": block.get("id"), "category": "tool"}
    if name in ("Read", "Edit", "Write"):
        path = rel_path(inp.get("file_path", ""), ws)
        step.update(path=path, category="read" if name == "Read" else "edit", summary=f"{name} {path}")
        if name == "Edit":
            step["detail"] = f"--- old\n{inp.get('old_string', '')}\n+++ new\n{inp.get('new_string', '')}"
        elif name == "Write":
            step["detail"] = inp.get("content", "")
    elif name == "Bash":
        cmd = strip_ws(inp.get("command", ""), ws)
        step.update(command=cmd, summary=cmd, detail=cmd, writes=bash_write_targets(cmd))
        if SIM_RE.search(cmd):
            step["category"] = "sim"
        elif step["writes"]:
            step["category"] = "edit"
        elif READ_CMD_RE.search(cmd):
            step["category"] = "read"
        else:
            step["category"] = "bash"
    elif name in ("Glob", "Grep"):
        step.update(category="search", summary=f"{name} {inp.get('pattern', '')} {rel_path(inp.get('path', ''), ws)}")
        step["path"] = rel_path(inp.get("path", ""), ws)
    else:
        step["summary"] = f"{name} {json.dumps(inp)[:120]}"
    step["raw_input"] = {k: (rel_path(v, ws) if isinstance(v, str) and k.endswith("path") else v)
                         for k, v in inp.items()}
    return step


def normalize(transcript: Path, timing: list[float], ws: Path) -> tuple[list[dict], dict]:
    """Returns (steps, info). info has the init model and the final result event."""
    steps: list[dict] = []
    calls: dict[str, dict] = {}
    info: dict = {}
    lines = [ln for ln in transcript.read_text(encoding="utf-8", errors="replace").splitlines() if ln.strip()]
    for li, line in enumerate(lines):
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        t = timing[li] if li < len(timing) else (timing[-1] if timing else 0.0)
        typ = ev.get("type")
        if typ == "system" and ev.get("subtype") == "init":
            info["model"] = ev.get("model")
            info["tools"] = ev.get("tools")
        elif typ == "result":
            info["result"] = ev
        elif typ in ("assistant", "user"):
            content = ev.get("message", {}).get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                bt = block.get("type")
                if typ == "assistant" and bt == "text" and block.get("text", "").strip():
                    txt = strip_ws(block["text"], ws)
                    steps.append({"kind": "assistant", "tool": None, "category": "message",
                                  "summary": _clip(txt, SUMMARY_MAX), "detail": txt, "text": txt, "t": t})
                elif typ == "assistant" and bt == "tool_use":
                    s = _call_step(block, ws)
                    s["t"] = t
                    steps.append(s)
                    calls[s["call_id"]] = s
                elif typ == "user" and bt == "tool_result":
                    call = calls.get(block.get("tool_use_id"), {})
                    out = strip_ws(_result_text(block.get("content")), ws)
                    if call.get("tool") == "Read":
                        out = LINE_NO_RE.sub("", out)  # drop the Read tool's "   12\t" prefixes
                    s = {"kind": "tool_result", "tool": call.get("tool"), "category": call.get("category", "tool"),
                         "call_id": block.get("tool_use_id"), "is_error": bool(block.get("is_error")),
                         "detail": out, "t": t, "output": out}
                    if call.get("category") == "sim":
                        s["sim_status"] = classify_sim_output(out)
                        first_fail = next((ln for ln in out.splitlines() if re.search(r"FAIL|ERROR|error", ln)), "")
                        s["summary"] = {"pass": "Simulation passed", "fail": f"Simulation failed: {_clip(first_fail, 120)}",
                                        "unknown": "Simulation output (no pass/fail marker)"}[s["sim_status"]]
                    else:
                        first = next((ln for ln in out.splitlines() if ln.strip()), "(empty)")
                        s["summary"] = ("Error: " if s["is_error"] else "") + _clip(first, SUMMARY_MAX)
                    steps.append(s)
    for i, s in enumerate(steps):
        s["i"] = i
        s["detail"] = _clip(s.get("detail", "") or "", DETAIL_MAX)
        s["summary"] = _clip(s.get("summary", "") or "", SUMMARY_MAX)
        s.setdefault("flag", None)
    return steps, info


def public_step(s: dict) -> dict:
    """Fields kept in results.json (drops bulky internal fields)."""
    keep = ("i", "t", "kind", "tool", "category", "summary", "detail", "flag", "sim_status", "is_error", "path")
    return {k: s[k] for k in keep if k in s and s[k] is not None}
