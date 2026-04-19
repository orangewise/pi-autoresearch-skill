# Upstream tracking

This repo is a **port**, not a fork, of [`davebcn87/pi-autoresearch`](https://github.com/davebcn87/pi-autoresearch). The original is built for the `pi` coding agent; this version targets **Claude Code**. The concepts are the same; the machinery is different.

## Pinned upstream revision

| Field | Value |
|---|---|
| Upstream repo | `https://github.com/davebcn87/pi-autoresearch` |
| Pinned commit | `5a29db080131449edc6d25a6b351b12879063366` |
| Short SHA | `5a29db0` |
| Ported on | `2026-04-18` |
| Upstream license | MIT |

When updating, bump `Pinned commit` and `Ported on`, and add a row to the changelog at the bottom of this file.

## Concept map (upstream → Claude Code)

| `pi-autoresearch` (upstream) | `pi-autoresearch-skill` (this port) |
|---|---|
| `extensions/pi-autoresearch/` (pi extension with TS tools) | `plugins/autoresearch/` (Claude Code plugin) |
| `skills/autoresearch-create/` (pi skill) | `plugins/autoresearch/skills/autoresearch/SKILL.md` |
| `skills/autoresearch-finalize/` (pi skill) | `plugins/autoresearch/skills/autoresearch-finalize/SKILL.md` |
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
