#!/usr/bin/env bash
# autoresearch benchmark script — template.
#
# Copy this to <project-root>/autoresearch.sh and customize.
#
# REQUIREMENT: emit at least one line matching:
#     METRIC <n>=<number>
#
# Examples of the METRIC line:
#     METRIC duration=42.3
#     METRIC bundle_kb=812
#     METRIC val_loss=0.1423

set -euo pipefail

# --- pre-checks (fail fast) ------------------------------------------------
# command -v uv >/dev/null || { echo "uv not installed" >&2; exit 1; }

# --- warmup (optional, reduces noise) --------------------------------------
# uv run pytest -q --collect-only >/dev/null 2>&1 || true

# --- measured workload -----------------------------------------------------
START=$(date +%s.%N)

# >>> REPLACE THIS WITH YOUR COMMAND <<<
uv run pytest -q

END=$(date +%s.%N)
DURATION=$(awk "BEGIN {printf \"%.3f\", $END - $START}")

# --- emit metric -----------------------------------------------------------
echo "METRIC duration=$DURATION"
