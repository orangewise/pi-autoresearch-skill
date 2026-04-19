# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **Claude Code plugin marketplace** entry that ports [davebcn87/pi-autoresearch](https://github.com/davebcn87/pi-autoresearch) to Claude Code. It contains one plugin (`autoresearch`) with one skill (`autoresearch`) that drives an autonomous experiment loop in any target project.

This repo is installed by users via:
```
/plugin marketplace add orangewise/pi-autoresearch-skill
/plugin install autoresearch@pi-autoresearch-skill
```

## Architecture

Two manifest layers govern how Claude Code discovers and loads the plugin:

- **`.claude-plugin/marketplace.json`** — top-level catalog; Claude Code reads this to list available plugins in this marketplace repo.
- **`plugins/autoresearch/.claude-plugin/plugin.json`** — per-plugin manifest; referenced by `marketplace.json` via `"source": "./plugins/autoresearch"`.

The plugin ships two skills, both under `plugins/autoresearch/skills/`:

- **`autoresearch/SKILL.md`** — the main experiment loop skill (start/resume a session, run forever).
- **`autoresearch-finalize/SKILL.md`** + **`finalize.sh`** — turns a noisy experiment branch into clean, independent, reviewable branches. `finalize.sh` is ported from upstream's Node.js version to python3.

Claude Code reads each skill's frontmatter (`name`, `description`) to decide when to activate it, and the body to know what to do. There are no compiled artifacts — skills are Markdown + shell scripts.

Helper scripts in `plugins/autoresearch/skills/autoresearch/scripts/` are **not** used directly in this repo; they are copied into target projects by `install-into-project.sh`. The `finalize.sh` is run directly from `${CLAUDE_PLUGIN_ROOT}` — it is not copied into target projects.

Upstream drift is tracked in `UPSTREAM.md` (pinned SHA) and checked by `scripts/check-upstream.sh` and a weekly GitHub Action.

## Versioning

When making changes, bump `version` in **both** manifest files together:
- `.claude-plugin/marketplace.json`
- `plugins/autoresearch/.claude-plugin/plugin.json`

## Checking upstream drift

```bash
bash scripts/check-upstream.sh
```

Exits 0 if in sync with the pinned upstream SHA, 1 if new commits exist. After porting upstream changes, update the pinned SHA and changelog in `UPSTREAM.md`.
