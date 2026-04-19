#!/usr/bin/env bash
# Print a table of results from autoresearch.jsonl.
#
# Usage:
#   results.sh                    # reads ./autoresearch.jsonl
#   results.sh path/to/log.jsonl  # reads a specific file
#   results.sh --higher-better    # treat higher metric as better (default: lower)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="autoresearch.jsonl"
DIRECTION="lower"

for arg in "$@"; do
  case "$arg" in
    --higher-better) DIRECTION="higher" ;;
    --lower-better)  DIRECTION="lower"  ;;
    -h|--help)
      echo "usage: $(basename "$0") [--higher-better|--lower-better] [path/to/log.jsonl]"
      exit 0
      ;;
    *) FILE="$arg" ;;
  esac
done

if [ ! -f "$FILE" ]; then
  echo "No $FILE found. Start a session with the autoresearch skill first." >&2
  exit 1
fi

python3 "$SCRIPT_DIR/results.py" "$FILE" "$DIRECTION"
