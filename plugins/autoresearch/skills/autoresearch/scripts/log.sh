#!/usr/bin/env bash
# Append a run entry to autoresearch.jsonl in the current working directory.
#
# Usage:
#   log.sh <metric_value> <status> "<description>" ['{"key": value}']
#
#   status ∈ {baseline, kept, reverted, failed, checks_failed}
#   4th arg (optional): JSON object of secondary metrics, e.g. '{"coverage": 94.2}'
#
# Examples:
#   log.sh 42.3 kept "enable pytest-xdist -n auto"
#   log.sh 42.3 kept "enable pytest-xdist -n auto" '{"coverage": 94.2, "flaky": 0}'

set -euo pipefail

if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "usage: $(basename "$0") <metric_value> <status> \"<description>\" ['{\"key\": value}']" >&2
  exit 2
fi

METRIC_VALUE="$1"
STATUS="$2"
DESCRIPTION="$3"
SECONDARY="${4:-}"

case "$STATUS" in
  baseline|kept|reverted|failed|checks_failed) ;;
  *)
    echo "error: status must be one of: baseline, kept, reverted, failed, checks_failed (got: $STATUS)" >&2
    exit 2
    ;;
esac

COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "none")
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "none")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -f autoresearch.jsonl ]; then
  RUN_N=$(( $(wc -l < autoresearch.jsonl) + 1 ))
else
  RUN_N=1
fi

# Escape double quotes in description for safe JSON embedding.
ESC_DESCRIPTION=${DESCRIPTION//\"/\\\"}

if [ -n "$SECONDARY" ]; then
  printf '{"run":%d,"timestamp":"%s","metric":%s,"status":"%s","branch":"%s","commit":"%s","description":"%s","metrics":%s}\n' \
    "$RUN_N" "$TIMESTAMP" "$METRIC_VALUE" "$STATUS" "$BRANCH" "$COMMIT" "$ESC_DESCRIPTION" "$SECONDARY" \
    >> autoresearch.jsonl
else
  printf '{"run":%d,"timestamp":"%s","metric":%s,"status":"%s","branch":"%s","commit":"%s","description":"%s"}\n' \
    "$RUN_N" "$TIMESTAMP" "$METRIC_VALUE" "$STATUS" "$BRANCH" "$COMMIT" "$ESC_DESCRIPTION" \
    >> autoresearch.jsonl
fi

echo "📝 run $RUN_N | $STATUS | metric=$METRIC_VALUE | $DESCRIPTION"
