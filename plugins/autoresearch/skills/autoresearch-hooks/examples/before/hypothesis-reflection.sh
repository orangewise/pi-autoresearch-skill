#!/usr/bin/env bash
# After a non-improvement, ask a cheap model to critique the failed attempt.
# Swap llm-cli for any short-prompt CLI (claude, llama-cli, ollama,
# a local endpoint via curl, etc.).

set -euo pipefail

readonly MODEL="claude-haiku-4-5"

fired_on_non_improvement() {
  local s
  s="$(jq -r '.last_run.status // empty' <<<"$1")"
  [ "$s" = "reverted" ] || [ "$s" = "failed" ] || [ "$s" = "checks_failed" ]
}

critique_prompt() {
  local desc="$1" status="$2"
  printf 'The attempt "%s" was %s.\n' "$desc" "$status"
  printf 'Name two adjacent directions that might work instead. One sentence each.'
}

ask_model() {
  llm-cli --model "$MODEL" --prompt "$1"
}

input="$(cat)"
fired_on_non_improvement "$input" || exit 0

desc=$(jq -r '.last_run.description // "unknown"' <<<"$input")
status=$(jq -r '.last_run.status' <<<"$input")
ask_model "$(critique_prompt "$desc" "$status")"
