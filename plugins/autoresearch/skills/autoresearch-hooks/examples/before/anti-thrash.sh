#!/usr/bin/env bash
# After N consecutive non-improvements, emit a steer suggesting a structural rethink.
# Counts any non-kept status (reverted/failed/checks_failed) in the recent window.

set -euo pipefail

readonly WINDOW_SIZE=5
readonly STREAK_THRESHOLD=5

recent_non_improvements() {
  tail -n "$WINDOW_SIZE" "$1" 2>/dev/null \
    | jq -r 'select(.status != "kept" and .status != "baseline") | .run' \
    | wc -l | tr -d ' '
}

thrash_suggestions() {
  echo "⚠️ $1 consecutive non-improvements. Consider:"
  echo "  - Re-reading autoresearch.md and the benchmark script"
  echo "  - Trying something structurally different, not another variation"
  echo "  - Measuring what the CPU is actually spending time on"
}

input="$(cat)"
jsonl="$(jq -r '.cwd' <<<"$input")/autoresearch.jsonl"
[ -f "$jsonl" ] || exit 0
streak=$(recent_non_improvements "$jsonl")

[ "$streak" -lt "$STREAK_THRESHOLD" ] && exit 0
thrash_suggestions "$streak"
