#!/usr/bin/env python3
"""
Print a results table from autoresearch.jsonl.

Usage:
    python3 results.py <path/to/autoresearch.jsonl> <lower|higher>
"""

import json
import sys


def load_runs(path):
    runs = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                runs.append(json.loads(line))
    return runs


def find_best(runs, direction):
    """Return the metric value of the best kept/baseline run, or None."""
    considered = [r for r in runs if r["status"] in ("baseline", "kept")]
    if not considered:
        return None
    if direction == "lower":
        return min(considered, key=lambda r: r["metric"])["metric"]
    return max(considered, key=lambda r: r["metric"])["metric"]


def format_table(runs, direction):
    """Return the full results table as a string."""
    best_metric = find_best(runs, direction)
    lines = []
    lines.append("")
    lines.append(
        f"  {'Run':>4}  {'Status':<13}  {'Metric':>10}  {'Commit':<8}  Description"
    )
    lines.append(f"  {'-' * 4}  {'-' * 13}  {'-' * 10}  {'-' * 8}  {'-' * 30}")
    for r in runs:
        is_best = (
            best_metric is not None
            and r["metric"] == best_metric
            and r["status"] in ("kept", "baseline")
        )
        marker = "  ◄ best" if is_best else ""
        lines.append(
            f"  {r['run']:>4}  {r['status']:<13}  {r['metric']:>10}"
            f"  {r.get('commit', 'none'):<8}  {r['description']}{marker}"
        )
    kept = sum(1 for r in runs if r["status"] == "kept")
    failed = sum(1 for r in runs if r["status"] in ("failed", "checks_failed"))
    lines.append("")
    lines.append(
        f"  Total: {len(runs)}  |  Kept: {kept}  |  Failed: {failed}"
        f"  |  Best ({direction} is better): {best_metric}"
    )
    lines.append("")
    return "\n".join(lines)


def main():
    if len(sys.argv) != 3:
        print(
            f"usage: {sys.argv[0]} <path/to/autoresearch.jsonl> <lower|higher>",
            file=sys.stderr,
        )
        sys.exit(2)

    path, direction = sys.argv[1], sys.argv[2]
    runs = load_runs(path)

    if not runs:
        print("No runs yet.")
        sys.exit(0)

    print(format_table(runs, direction))


if __name__ == "__main__":
    main()
