---
name: autoresearch
description: Run an autonomous experiment loop to optimize a measurable metric. Use when the user wants to iteratively improve something benchmarkable — test speed, build time, bundle size, training loss, Lighthouse scores, CDK synth time, Lambda cold start, anything where a command can produce a number. Triggers on phrases like "optimize", "make X faster", "reduce Y", "autoresearch", or an explicit request to set up an experiment loop. Not for one-shot performance analysis — this is specifically for the try-measure-keep-or-revert loop that runs indefinitely.
license: MIT
---

# autoresearch

Autonomous experiment loop: try ideas, keep what works, discard what doesn't, never stop. Ported from [davebcn87/pi-autoresearch](https://github.com/davebcn87/pi-autoresearch) for Claude Code.

## When to use

Any optimization target where a command produces a number:

- Test suite speed (`uv run pytest`)
- Build time (`cdk synth`, `npm run build`)
- Bundle size, image size, binary size
- Cold-start latency, p99 response time
- Model training metrics (loss, accuracy)

## Session files

Five files live in the **project root** and make the loop resumable across context resets:

| File | Purpose |
|---|---|
| `autoresearch.md` | Living session doc — objective, metrics, scope, what's been tried. A fresh agent reads this and continues. |
| `autoresearch.jsonl` | Append-only run log — one JSON object per run. Never rewrite; always go through `log.sh`. |
| `autoresearch.sh` | Benchmark script. Must emit `METRIC name=value` lines. |
| `autoresearch.checks.sh` | *(optional)* Correctness backpressure — tests, types, lint. Runs after every passing benchmark. |
| `autoresearch.ideas.md` | *(optional)* Ideas backlog for complex/deferred hypotheses. |
| `autoresearch.config.json` | *(optional)* Session config — `maxIterations`, `workingDir`, `direction`, `metricName`, `metricUnit`. |
| `autoresearch.hooks/before.sh` | *(optional)* Hook run before each iteration. See the `autoresearch-hooks` skill. |
| `autoresearch.hooks/after.sh` | *(optional)* Hook run after each `log.sh` call. See the `autoresearch-hooks` skill. |

All `autoresearch.*` paths (including `autoresearch.hooks/**`) survive the loop's revert step.

> **Note on `jq`.** `run-hook.sh` needs `jq` on PATH to build the hook input JSON. If `jq` is missing, the hook is silently skipped. Install with `brew install jq` / `apt install jq`.

Helper scripts (copy into project once with `install-into-project.sh`):

| Script | Purpose |
|---|---|
| `log.sh` | Append a run to `autoresearch.jsonl` |
| `results.sh` | Print a results table |
| `bench-template.sh` | Starting template for `autoresearch.sh` |
| `run-hook.sh` | Invoke `autoresearch.hooks/{before,after}.sh` with synthesized JSON stdin |
| `compact-summary.py` | Print a deterministic 6-section summary for resuming after context compaction |

## First-time project setup

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/scripts/install-into-project.sh"
git add scripts/autoresearch && git commit -m "add autoresearch helper scripts"
```

Skip if `scripts/autoresearch/` already exists in the project.

## Starting a session

1. Check whether `autoresearch.md` exists in the project root.
   - **Exists** → read it and `autoresearch.jsonl`. Report current best, run count, last few attempts. Skip to "The loop".
   - **Missing** → continue with new-session setup.

2. Gather (ask or infer from conversation):

   | Question | Example |
   |---|---|
   | Objective | "Make the test suite faster" |
   | Benchmark command | `uv run pytest -q` |
   | Primary metric + direction | `duration`, lower is better |
   | Secondary metrics to monitor | `coverage`, `flaky_count` |
   | Files in scope | `pyproject.toml`, `tests/conftest.py` |
   | Constraints | "Tests must pass", "no new deps" |
   | Out of scope | "Don't touch production code" |

3. Read the source files in scope. Understand the workload deeply before writing anything.

4. Create a git branch: `git checkout -b autoresearch/<slug>`.

5. Write `autoresearch.sh` from the bench-template (see below). For **fast, noisy benchmarks** (< 5s), run the workload multiple times inside the script and report the median — this stabilizes the signal from the start.

6. If the user has correctness constraints ("tests must pass"), write `autoresearch.checks.sh`.

7. Write `autoresearch.md` (template below). Commit `autoresearch.sh`, `autoresearch.md`, and `autoresearch.checks.sh` if created.

8. Run the baseline: `bash autoresearch.sh`. Parse the `METRIC` line.

9. Log baseline:
   ```bash
   bash scripts/autoresearch/log.sh "<value>" baseline "baseline run"
   ```

10. Begin the loop.

### autoresearch.md template

```markdown
# Autoresearch: <goal>

## Objective
<Specific description of what we're optimizing and the workload.>

## Metrics
- **Primary**: <name> (<unit>, lower/higher is better) — the optimization target
- **Secondary**: <name>, <name>, ... — independent tradeoff monitors

## How to Run
`bash autoresearch.sh` — outputs `METRIC name=number` lines.

## Files in Scope
<Every file the agent may modify, with a brief note on what it does.>

## Constraints
<Hard rules: tests must pass, no new deps, etc.>

## Off Limits
<What must NOT be touched.>

## What's Been Tried
<!-- Update this as experiments accumulate. Note key wins, dead ends, architectural insights. -->
- Run 0 | <baseline_value> | baseline | initial measurement
```

### autoresearch.sh design

The script should output **whatever data helps make better decisions**:

- Phase timings when the workload has distinct stages
- Error counts, failure categories when checks can fail in different ways
- Memory usage, cache hit rates, or other runtime diagnostics

The script can be **updated during the loop** — add instrumentation as you learn what matters.

Keep the script fast. Every second is multiplied by hundreds of runs.

### autoresearch.checks.sh (optional)

Create this file when the user's constraints require correctness validation ("tests must pass", "types must check"). **Only create it when required** — don't add it speculatively.

```bash
#!/usr/bin/env bash
set -euo pipefail
# Suppress success output — only show errors, keep context lean.
pnpm test --run --reporter=dot 2>&1 | tail -50
pnpm typecheck 2>&1 | grep -i error || true
```

When this file exists:
- Runs automatically after every **passing** benchmark.
- If checks fail, log as `checks_failed` and revert — you cannot keep a result when checks have failed.
- Checks execution time does **not** affect the primary metric.

### autoresearch.config.json (optional)

Create in the project root to configure session behaviour:

```json
{
  "workingDir": "/path/to/project",
  "maxIterations": 50
}
```

| Field | Description |
|---|---|
| `workingDir` | Override the directory for all autoresearch file I/O, command execution, and git operations. Absolute or relative to the session cwd. Fails if the directory doesn't exist. |
| `maxIterations` | Maximum experiments before stopping. Useful for cost control on long-running loops. |
| `direction` | `"lower"` or `"higher"`. Used by `results.sh`, `run-hook.sh`, and `compact-summary.py` to identify the best metric. Defaults to `"lower"`. |
| `metricName` | Display name for the primary metric (e.g. `"duration"`). Used by hooks and the compaction summary. |
| `metricUnit` | Display unit (e.g. `"s"`, `"ms"`, `"KB"`). Used by hooks and the compaction summary. |

## The loop

**LOOP FOREVER. Never ask "should I continue?" — the user expects autonomous work. NEVER STOP until interrupted.**

### 0. Before-hook (optional)
If `autoresearch.hooks/before.sh` exists and is executable, run:
```bash
bash scripts/autoresearch/run-hook.sh before
```
Its stdout is a steer for this iteration — read it before hypothesizing. Silent output = nothing to do.

### 1. Hypothesize
Pick one specific change. Consult "What's Been Tried", `autoresearch.ideas.md`, and any output from the before-hook. State the hypothesis in one sentence.

### 2. Implement
Make the change. Keep the diff focused — one idea per run. Respect constraints and off-limits boundaries.

### 3. Benchmark
```bash
bash autoresearch.sh
```
Extract the value from the `METRIC name=<value>` line. If the script exits non-zero or no METRIC line is emitted, treat as `failed`.

If `autoresearch.checks.sh` exists and the benchmark passed, run it:
```bash
bash autoresearch.checks.sh
```
If checks fail, treat as `checks_failed`.

### 4. Decide

| Result | Action |
|---|---|
| Primary metric improved | `git add -A && git commit -m "autoresearch: <description> (<value>)"` → status `kept` |
| Not improved (benchmark) | `git checkout -- .` → status `reverted` |
| Benchmark failed | `git checkout -- .` → status `failed` |
| Checks failed | `git checkout -- .` → status `checks_failed` |

**Confidence score:** After 3+ runs, compare the best improvement to the session noise floor (how much metrics vary run-to-run). A confidence ≥ 2× the noise means the improvement is likely real. < 1× means it may be within noise — consider re-running to confirm before keeping. This is advisory: never auto-discard based on it.

### 5. Log
```bash
bash scripts/autoresearch/log.sh "<metric_value>" "<kept|reverted|failed|checks_failed>" "<short description>" '{"secondary_metric": value}'
```
The fourth argument is optional JSON for secondary metrics. Omit it if not tracking secondaries.

### 5b. After-hook (optional)
If `autoresearch.hooks/after.sh` exists and is executable, run:
```bash
bash scripts/autoresearch/run-hook.sh after
```
Its stdout (if any) is context for the next iteration.

### 6. Update autoresearch.md
Append a line to **What's Been Tried**. If the idea is a dead end (regressed or has a structural reason to fail), note it with a one-line reason so future iterations don't repeat it.

**Annotate failures and crashes heavily.** Discarded runs revert the code — the only surviving record is the description and secondary metrics in `autoresearch.jsonl`. Capture what was tried and why it failed, or future iterations will rediscover the same dead ends.

### 7. Ideas backlog
When you discover complex but promising optimizations you won't pursue right now, append them to `autoresearch.ideas.md`. On resume (context limit, crash), check this file — prune stale/tried entries, experiment with the rest. When all paths are exhausted, delete it and write a final summary in `autoresearch.md`.

### 8. Status line
```
🔬 Run N | <value> | kept/reverted | best: <best_value>
```

### 9. Continue
Immediately begin the next iteration. **Do not pause for confirmation.** If the user sends a message while an experiment is running, finish the current benchmark + log cycle first, then incorporate their feedback in the next iteration.

## Rules

- **Primary metric is king.** Improved → keep. Worse/equal → revert. Secondary metrics rarely override this.
- **Simpler is better.** Removing code for equal performance = keep. Ugly complexity for tiny gain = probably revert.
- **Don't thrash.** Repeatedly reverting the same idea? Try something structurally different.
- **Think longer when stuck.** Re-read source files, study output, reason about what the CPU is actually doing. The best ideas come from deep understanding, not random variations.
- **Crashes:** fix if trivial, otherwise log and move on. Don't over-invest.
- **Branch isolation.** Each session runs on its own branch. Never run on `main`.

## Long-running loops and context

Claude Code auto-compacts when context fills — trust it. Don't budget tokens or predict your own next iteration's footprint.

When a compaction window is imminent (or when starting a fresh session on an existing branch), run:

```bash
python3 scripts/autoresearch/compact-summary.py
```

It prints a deterministic six-section markdown block (Session / Experiment Rules / Ideas Backlog / Recent Runs / Next Step) that embeds `autoresearch.md` and `autoresearch.ideas.md` and tails the last 50 runs from `autoresearch.jsonl`. A resuming agent reading that summary has everything needed to continue — no need to re-read the source files.

## Viewing progress

```bash
bash scripts/autoresearch/results.sh              # lower-is-better (default)
bash scripts/autoresearch/results.sh --higher-better
```

## Finalizing

When done, use the `autoresearch-finalize` skill to turn the noisy experiment branch into clean, independent, reviewable branches — one per logical change.
