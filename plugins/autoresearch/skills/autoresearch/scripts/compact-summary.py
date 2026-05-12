#!/usr/bin/env python3
"""Deterministic compaction summary for an autoresearch session.

Reads the session files in the current working directory and prints a
six-section markdown block to stdout. Run this **before** Claude Code
auto-compacts (or right after resuming a session) to seed a fresh
context with everything needed to keep iterating.

The output mirrors upstream pi-autoresearch's `compaction.ts` summary so
that anyone reading either codebase's session sees the same shape.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

RECENT_RUN_LIMIT = 50


def load_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    out: list[dict] = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return out


def load_config(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return {}


def read_text(path: Path) -> str:
    return path.read_text() if path.exists() else ""


def best_of(runs: list[dict], direction: str) -> dict | None:
    kept = [r for r in runs if r.get("status") == "kept" and "metric" in r]
    if not kept:
        return None
    reverse = direction == "higher"
    return sorted(kept, key=lambda r: r["metric"], reverse=reverse)[0]


def baseline_of(runs: list[dict]) -> dict | None:
    for r in runs:
        if r.get("status") == "baseline":
            return r
    return None


def fmt_metric(value, unit: str) -> str:
    if value is None:
        return "—"
    return f"{value}{unit}" if unit else f"{value}"


def fmt_delta(value, baseline, direction: str) -> str:
    if value is None or baseline is None or baseline == 0:
        return ""
    pct = (value - baseline) / abs(baseline) * 100
    sign = "+" if pct >= 0 else ""
    arrow = ""
    if direction == "lower":
        arrow = " ✓" if pct < 0 else " ✗"
    elif direction == "higher":
        arrow = " ✓" if pct > 0 else " ✗"
    return f" ({sign}{pct:.1f}%{arrow})"


def goal_from_md(text: str) -> str:
    for line in text.splitlines():
        if line.startswith("# "):
            return line[2:].removeprefix("Autoresearch: ").strip()
    return ""


def status_counts(runs: list[dict]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for r in runs:
        s = r.get("status", "?")
        counts[s] = counts.get(s, 0) + 1
    return counts


def main() -> int:
    cwd = Path(os.getcwd())
    runs = load_jsonl(cwd / "autoresearch.jsonl")
    config = load_config(cwd / "autoresearch.config.json")
    md_text = read_text(cwd / "autoresearch.md")
    ideas_text = read_text(cwd / "autoresearch.ideas.md")

    direction = config.get("direction", "lower")
    metric_name = config.get("metricName", "metric")
    metric_unit = config.get("metricUnit", "")
    goal = goal_from_md(md_text)

    baseline = baseline_of(runs)
    best = best_of(runs, direction)
    counts = status_counts(runs)

    out: list[str] = []
    out.append("# Autoresearch Compaction Summary\n")

    out.append("## Session")
    out.append(f"- **Goal**: {goal or '—'}")
    out.append(
        f"- **Metric**: {metric_name} ({metric_unit or 'unitless'}, {direction} is better)"
    )
    if counts:
        joined = ", ".join(f"{k}={v}" for k, v in sorted(counts.items()))
        out.append(f"- **Runs**: {len(runs)} ({joined})")
    else:
        out.append("- **Runs**: 0")
    if baseline:
        out.append(f"- **Baseline**: {fmt_metric(baseline.get('metric'), metric_unit)}")
    if best:
        delta = fmt_delta(
            best.get("metric"), baseline.get("metric") if baseline else None, direction
        )
        out.append(
            f"- **Best**: {fmt_metric(best.get('metric'), metric_unit)}{delta} (run {best.get('run')})"
        )
    out.append("")

    out.append("## Experiment Rules (autoresearch.md)")
    out.append(md_text.strip() or "_(missing)_")
    out.append("")

    out.append("## Ideas Backlog (autoresearch.ideas.md)")
    out.append(ideas_text.strip() or "_(empty)_")
    out.append("")

    recent = runs[-RECENT_RUN_LIMIT:]
    out.append(f"## Recent Runs (last {len(recent)})")
    base_metric = baseline.get("metric") if baseline else None
    for r in recent:
        delta = (
            ""
            if r.get("status") == "baseline"
            else fmt_delta(r.get("metric"), base_metric, direction)
        )
        out.append(
            f"- #{r.get('run')} {r.get('status')} "
            f"{fmt_metric(r.get('metric'), metric_unit)}{delta} | "
            f"{r.get('description', '')}"
        )
    out.append("")

    out.append("## Next Step")
    out.append(
        "Pick the most promising hypothesis from the ideas backlog or the latest "
        "descriptions in recent runs, then run `bash autoresearch.sh` + "
        "`bash scripts/autoresearch/log.sh ...`. Do not re-read `autoresearch.md` "
        "or `autoresearch.jsonl` — this summary already embeds them."
    )

    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
