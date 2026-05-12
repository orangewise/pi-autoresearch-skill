# Upstream tracking

This repo is a **port**, not a fork, of [`davebcn87/pi-autoresearch`](https://github.com/davebcn87/pi-autoresearch). The original is built for the `pi` coding agent; this version targets **Claude Code**. The concepts are the same; the machinery is different.

## Pinned upstream revision

| Field | Value |
|---|---|
| Upstream repo | `https://github.com/davebcn87/pi-autoresearch` |
| Pinned commit | `84232861a09e753f63bceda46852f0ddbb4c9afd` |
| Short SHA | `8423286` |
| Ported on | `2026-05-12` |
| Upstream license | MIT |

When updating, bump `Pinned commit` and `Ported on`, and add a row to the changelog at the bottom of this file.

## Concept map (upstream → Claude Code)

| `pi-autoresearch` (upstream) | `pi-autoresearch-skill` (this port) |
|---|---|
| `extensions/pi-autoresearch/` (pi extension with TS tools) | `plugins/autoresearch/` (Claude Code plugin) |
| `skills/autoresearch-create/` (pi skill) | `plugins/autoresearch/skills/autoresearch/SKILL.md` |
| `skills/autoresearch-finalize/` (pi skill) | `plugins/autoresearch/skills/autoresearch-finalize/SKILL.md` |
| `skills/autoresearch-hooks/` (pi skill) | `plugins/autoresearch/skills/autoresearch-hooks/SKILL.md` |
| `extensions/pi-autoresearch/hooks.ts` (auto-invoked by pi) | `scripts/run-hook.sh` (agent invokes manually in the loop) |
| `extensions/pi-autoresearch/compaction.ts` (`session_before_compact`) | `scripts/compact-summary.py` (agent invokes before/after compaction) |
| `skills/autoresearch-finalize/finalize.sh` (uses Node.js) | `plugins/autoresearch/skills/autoresearch-finalize/finalize.sh` (ported to python3) |
| Tool: `init_experiment` | "Starting a session" section of `SKILL.md` |
| Tool: `run_experiment` | `bash autoresearch.sh` via Bash tool |
| Tool: `log_experiment` (primary + secondary metrics, `asi`) | `scripts/log.sh` (primary + optional secondary metrics JSON) |
| `/autoresearch` dashboard command (pi UI widget) | `scripts/results.sh` (terminal table) |
| `pi install <url>` | `/plugin marketplace add` + `/plugin install` |
| Session files `autoresearch.md`, `autoresearch.jsonl`, `autoresearch.sh` | Identical — same format, same names |
| `autoresearch.checks.sh`, `autoresearch.config.json`, `autoresearch.ideas.md` | Identical — same concept, documented in `SKILL.md` |

The session-file contract is preserved verbatim on purpose: any future tooling from upstream that reads `autoresearch.jsonl` or `autoresearch.md` will work with sessions produced by this port, and vice versa.

## Checking for upstream changes

Run:

```bash
bash scripts/check-upstream.sh
```

This compares the pinned commit against upstream `HEAD` and prints the commits in between with one-line summaries. If changes touch `extensions/pi-autoresearch/`, `skills/autoresearch-create/`, `skills/autoresearch-finalize/`, or the README, they likely warrant a port.

A GitHub Action (`.github/workflows/check-upstream.yml`) runs this weekly and opens an issue if new upstream commits exist.

## Porting workflow

1. `bash scripts/check-upstream.sh` → review commits since the pinned SHA
2. For each relevant upstream change, port the concept (not the TypeScript) into the SKILL.md / scripts
3. Bump versions in both `.claude-plugin/marketplace.json` and `plugins/autoresearch/.claude-plugin/plugin.json`
4. Update the pinned SHA above and add a changelog entry
5. Open a PR; CI validates the marketplace and plugin manifests

## Changelog

| Date | This version | Upstream SHA | Notes |
|---|---|---|---|
| 2026-04-18 | 0.1.0 | `5a29db0` | Initial port. Skill + session-file contract + helper scripts. |
| 2026-05-12 | 0.2.0 | `8423286` | Catch-up to upstream v1.4.0. **Ported:** v1.1.0 hooks (new `autoresearch-hooks` skill, `run-hook.sh` wrapper, adapted examples), v1.2.0 trust auto-compaction (added "Long-running loops and context" section), v1.3.0 deterministic compaction summary (`compact-summary.py`). **N/A for Claude Code:** v1.0.1 (pi resume-timer / `/off` abort / `patternProperties` schema / dashboard shortcut fixes — pi-extension-specific), v1.4.0 (configurable pi dashboard shortcuts — pi UI-specific). Hook examples adapted to our status names (`kept`/`reverted`/`failed`/`checks_failed`) and absence of an `asi` sub-object in `autoresearch.jsonl`. |
