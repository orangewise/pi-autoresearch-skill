#!/usr/bin/env bash
# Invoke autoresearch.hooks/{before,after}.sh with a synthesized JSON stdin.
#
# Usage:
#   run-hook.sh before          # before next iteration (uses last jsonl line as last_run)
#   run-hook.sh after           # after log.sh (uses last jsonl line as run_entry)
#
# Exits 0 silently if the hook file is missing or not executable, mirroring
# the upstream pi-autoresearch contract.

set -euo pipefail

STAGE="${1:-}"
case "$STAGE" in
  before|after) ;;
  *) echo "usage: $(basename "$0") before|after" >&2; exit 2 ;;
esac

HOOK="autoresearch.hooks/${STAGE}.sh"
[ -x "$HOOK" ] || exit 0

command -v jq >/dev/null 2>&1 || { echo "run-hook: jq is required" >&2; exit 0; }

JSONL="autoresearch.jsonl"
MD="autoresearch.md"
CONFIG="autoresearch.config.json"
CWD="$(pwd)"

# --- session block --------------------------------------------------------
direction="lower"
metric_name="metric"
metric_unit=""
goal=""

if [ -f "$CONFIG" ]; then
  direction=$(jq -r '.direction // "lower"' "$CONFIG")
  metric_name=$(jq -r '.metricName // "metric"' "$CONFIG")
  metric_unit=$(jq -r '.metricUnit // ""' "$CONFIG")
fi
if [ -f "$MD" ]; then
  goal=$(grep -m1 '^# ' "$MD" 2>/dev/null | sed 's/^# *Autoresearch: *//; s/^# *//' || true)
fi

run_count=0
baseline_metric=null
best_metric=null
last_line=""
if [ -f "$JSONL" ]; then
  run_count=$(wc -l < "$JSONL" | tr -d ' ')
  baseline_metric=$(jq -r 'select(.status=="baseline") | .metric' "$JSONL" 2>/dev/null | head -n1)
  [ -z "$baseline_metric" ] && baseline_metric=null
  if [ "$direction" = "higher" ]; then
    best_metric=$(jq -r 'select(.status=="kept") | .metric' "$JSONL" 2>/dev/null | sort -g | tail -n1)
  else
    best_metric=$(jq -r 'select(.status=="kept") | .metric' "$JSONL" 2>/dev/null | sort -g | head -n1)
  fi
  [ -z "$best_metric" ] && best_metric=null
  last_line=$(tail -n1 "$JSONL" 2>/dev/null || true)
fi

session=$(jq -n \
  --arg name "$metric_name" \
  --arg unit "$metric_unit" \
  --arg dir "$direction" \
  --argjson baseline "$baseline_metric" \
  --argjson best "$best_metric" \
  --argjson count "$run_count" \
  --arg goal "$goal" \
  '{metric_name:$name, metric_unit:$unit, direction:$dir,
    baseline_metric:$baseline, best_metric:$best,
    run_count:$count, goal:$goal}')

# --- event-specific block -------------------------------------------------
if [ "$STAGE" = "before" ]; then
  next_run=$((run_count + 1))
  if [ -n "$last_line" ]; then
    last_run="$last_line"
  else
    last_run="null"
  fi
  payload=$(jq -n \
    --arg cwd "$CWD" \
    --argjson next "$next_run" \
    --argjson last "$last_run" \
    --argjson session "$session" \
    '{event:"before", cwd:$cwd, next_run:$next, last_run:$last, session:$session}')
else
  if [ -z "$last_line" ]; then
    # Nothing to report on; skip silently.
    exit 0
  fi
  payload=$(jq -n \
    --arg cwd "$CWD" \
    --argjson entry "$last_line" \
    --argjson session "$session" \
    '{event:"after", cwd:$cwd, run_entry:$entry, session:$session}')
fi

# --- invoke ---------------------------------------------------------------
# 30s soft timeout via `timeout` if available; otherwise run directly.
if command -v timeout >/dev/null 2>&1; then
  printf '%s\n' "$payload" | timeout 30 "$HOOK"
else
  printf '%s\n' "$payload" | "$HOOK"
fi
