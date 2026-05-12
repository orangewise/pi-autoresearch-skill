---
name: autoresearch-hooks
description: Optional before/after hooks that fire at iteration boundaries in an autoresearch session. Use when the user wants to extend the loop with research lookups, notifications, anti-thrash steering, or learnings journaling without modifying the main skill. Triggers when the user mentions "autoresearch hook", "before each iteration", "after each run", "notify on best", "auto-tag", or similar lifecycle automation.
license: MIT
---

# autoresearch-hooks

Optional scripts that the autoresearch loop calls at iteration boundaries. Two hooks, both invoked by the agent (via `scripts/autoresearch/run-hook.sh`) — their effect is a file on disk or stdout that the agent reads on the next turn.

```
autoresearch.hooks/
  before.sh    # fires before each iteration (prospective)
  after.sh     # fires after each log.sh call (retrospective)
```

Both files are optional. Files without the executable bit are silently ignored.

---

## Lifecycle

The main `autoresearch` skill invokes hooks via the wrapper `bash scripts/autoresearch/run-hook.sh before|after` at two points per iteration:

1. **Before** — right before the hypothesize step. Wrapper synthesizes input JSON from session files (`autoresearch.md` for goal, `autoresearch.jsonl` for last_run / best_metric / baseline_metric / run_count) and pipes it to `autoresearch.hooks/before.sh`.
2. **After** — right after `log.sh` appends the new run. Wrapper reads the just-appended jsonl line as `run_entry` and pipes the same `session` shape.

If the hook prints to stdout, the agent treats it as a steer for the next decision. Empty stdout = silent.

## Contract

### Stdin — `before.sh`

One JSON line. Parse with `jq`. Realistic example:

```json
{
  "event": "before",
  "cwd": "/path/to/workdir",
  "next_run": 6,
  "last_run": {
    "run": 5,
    "status": "reverted",
    "metric": 42.1,
    "description": "Simplified to sorted(arr) — copy cost dominates",
    "metrics": { "coverage": 94.2 }
  },
  "session": {
    "metric_name": "duration",
    "metric_unit": "s",
    "direction": "lower",
    "baseline_metric": 40.7,
    "best_metric": 33.5,
    "run_count": 5,
    "goal": "Make the test suite faster"
  }
}
```

| Field | Notes |
|---|---|
| `last_run` | Most recent jsonl line. `null` on a fresh session. |
| `last_run.status` | One of `baseline`, `kept`, `reverted`, `failed`, `checks_failed`. |
| `last_run.metrics` | Optional secondary-metrics object (the 4th arg to `log.sh`). |
| `session.direction` | `"lower"` or `"higher"` — derived from `autoresearch.config.json` or defaults to `"lower"`. |
| `session.baseline_metric` | First (`baseline`) run's metric. `null` until the baseline is logged. |
| `session.best_metric` | Best metric across `kept` runs only. `null` until one is kept. |
| `session.goal` | First H1 heading in `autoresearch.md`. |
| `session.run_count` | Total runs logged so far (any status). |

### Stdin — `after.sh`

```json
{
  "event": "after",
  "cwd": "/path/to/workdir",
  "run_entry": {
    "run": 6,
    "status": "reverted",
    "metric": 38.9,
    "description": "Timsort hybrid slower on random",
    "metrics": {}
  },
  "session": { /* same shape as before.sh, post-run */ }
}
```

### Output

- **Stdout** (up to 8 KB by convention) — delivered to the agent as a steer message. Empty = silent.
- **Non-zero exit** — surfaced as an error steer. Don't fail the loop on it.
- **Timeouts** — wrapper enforces a 30 s soft timeout via `timeout 30`.

### Preservation across revert

`autoresearch.hooks/**` matches the `autoresearch.*` glob and is preserved by the loop's `git checkout -- .` revert step. See the main skill's revert rules.

> **Status-name note.** Upstream pi uses `keep` / `discard`; this Claude Code port uses `kept` / `reverted` / `failed` / `checks_failed`. Examples here use the port's names. If you adapt a script from the upstream repo, translate accordingly.

---

## Examples

Reference scripts live under `examples/`. They're not policy — copy, adapt, mark executable.

- `examples/before/` — `anti-thrash.sh`, `context-rotation.sh`, `external-search.sh`, `hypothesis-reflection.sh`, `idea-rotator.sh`, `qmd-search.sh`
- `examples/after/` — `auto-tag-winners.sh`, `learnings-journal.sh`, `macos-notify.sh`

---

## Steps to add a hook

1. **Understand the session.** Read `autoresearch.md` for the objective and metric; glance at `autoresearch.sh` for the workload. Your hook should complement the loop, not duplicate it.

2. **Clarify the user's intent.** What should happen, at which boundary? Research before / journaling after / notify on wins / intervene on thrash.

3. **Start from an example** closest to the intent. If nothing fits, write from scratch following the same style (named constants, short functions, guard clauses, JSON stdin parsed with `jq`).

4. **Copy, adapt, mark executable.**

   ```bash
   mkdir -p autoresearch.hooks
   cp "${CLAUDE_PLUGIN_ROOT}/skills/autoresearch-hooks/examples/before/external-search.sh" \
      autoresearch.hooks/before.sh
   chmod +x autoresearch.hooks/before.sh
   ```

5. **Sanity-test with a piped mock** before relying on it in the loop:

   ```bash
   jq -n '{
     event:"before", cwd:".", next_run:1, last_run:null,
     session:{metric_name:"duration", metric_unit:"s", direction:"lower",
              baseline_metric:null, best_metric:null, run_count:0, goal:"test"}
   }' | ./autoresearch.hooks/before.sh
   ```

6. **Commit the hook** with other session files. The revert glob preserves it across iterations.

---

## Rules of thumb

- **Read what the agent actually writes** — `description`, `metric`, `status`, `metrics`. The Claude Code port has no `asi` sub-object; do not invent fields and instruct the agent to populate them.
- **Silent is the default.** Only print to stdout when you have something useful. Empty stdout = no steer.
- **Guard with early exits.** `[ -z "$query" ] && exit 0` is cheaper and clearer than nested `if`.
- **One concern per script.** Research + learnings? Use both `before.sh` and `after.sh`. Don't bundle.
- **No environment variables.** Everything is on stdin; extract with `jq`. There is no `$AUTORESEARCH_WORK_DIR`.
