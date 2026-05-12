# autoresearch — Claude Code plugin marketplace

> Try an idea, measure it, keep what works, discard what doesn't, repeat forever.

A **Claude Code plugin marketplace** that ports [davebcn87/pi-autoresearch](https://github.com/davebcn87/pi-autoresearch) — the autonomous experiment loop — from the `pi` coding agent to **Claude Code**.

## Install

In Claude Code:

```
/plugin marketplace add orangewise/pi-autoresearch-skill
/plugin install autoresearch@pi-autoresearch-skill
```

Then, in any project you want to optimize, copy the helper scripts in once:

```
bash "${CLAUDE_PLUGIN_ROOT}/skills/autoresearch/scripts/install-into-project.sh"
git add scripts/autoresearch && git commit -m "add autoresearch helper scripts"
```

## Usage

Just talk to Claude Code:

> "Start an autoresearch session to speed up our test suite."
> "Optimize CDK synth time — it's taking 40 seconds."
> "Resume the autoresearch session."

Claude Code will pick up the skill automatically from the description.

When you're done experimenting, finalize into clean, reviewable branches:

> "Finalize autoresearch."

Claude Code will group kept experiments into logical changesets, get your approval, then create independent branches from the merge-base — one per group, each ready to review and merge separately.

You can also view your results table at any time:

```bash
bash scripts/autoresearch/results.sh
bash scripts/autoresearch/results.sh --higher-better   # for metrics like accuracy
```

## How it works

The skill drives an autonomous loop:

```
hypothesize → implement → bash autoresearch.sh → compare → keep/revert → log → repeat
```

Session files in your project root make it resumable across context resets:

| File | Purpose |
|---|---|
| `autoresearch.md` | Living session doc — objective, metrics, scope, what's been tried |
| `autoresearch.jsonl` | Append-only run log — one JSON object per run |
| `autoresearch.sh` | Your benchmark script (Claude writes this for you) |
| `autoresearch.checks.sh` | *(optional)* Correctness checks — tests, types, lint |
| `autoresearch.ideas.md` | *(optional)* Ideas backlog for deferred hypotheses |
| `autoresearch.config.json` | *(optional)* Config — `maxIterations`, `workingDir`, `direction`, `metricName`, `metricUnit` |
| `autoresearch.hooks/before.sh` | *(optional)* Hook run before each iteration |
| `autoresearch.hooks/after.sh` | *(optional)* Hook run after each `log.sh` |

Helper scripts (installed into `scripts/autoresearch/`):

| Script | Purpose |
|---|---|
| `log.sh` | Append a run to `autoresearch.jsonl` |
| `results.sh` / `results.py` | Print a results table |
| `bench-template.sh` | Starting template for `autoresearch.sh` |
| `run-hook.sh` | Invoke `autoresearch.hooks/{before,after}.sh` with synthesized JSON stdin (requires `jq`) |
| `compact-summary.py` | Print a deterministic six-section summary for resuming after context compaction |

## Hooks

Optional before/after hooks let you extend the loop with research lookups, notifications, anti-thrash steering, or learnings journaling without touching the main skill. See the `autoresearch-hooks` skill for the contract and copy-paste examples under `examples/{before,after}/`.

## Repo layout

```
.
├── .claude-plugin/
│   └── marketplace.json          # Marketplace catalog (what Claude Code reads)
├── .github/
│   └── workflows/
│       └── check-upstream.yml    # Weekly upstream diff check → opens GitHub issue
├── plugins/
│   └── autoresearch/
│       ├── .claude-plugin/
│       │   └── plugin.json       # Plugin manifest
│       └── skills/
│           ├── autoresearch/
│           │   ├── SKILL.md      # Main experiment loop skill
│           │   └── scripts/
│           │       ├── log.sh
│           │       ├── results.sh
│           │       ├── results.py
│           │       ├── bench-template.sh
│           │       ├── run-hook.sh
│           │       ├── compact-summary.py
│           │       └── install-into-project.sh
│           ├── autoresearch-hooks/
│           │   ├── SKILL.md      # Optional before/after iteration hooks
│           │   └── examples/
│           │       ├── before/   # external-search, idea-rotator, anti-thrash, ...
│           │       └── after/    # auto-tag-winners, learnings-journal, macos-notify
│           └── autoresearch-finalize/
│               ├── SKILL.md      # Finalize session into reviewable branches
│               └── finalize.sh
├── scripts/
│   └── check-upstream.sh         # Local upstream diff tool
├── UPSTREAM.md                   # Port relationship, pinned SHA, concept map, changelog
└── README.md
```

## Upstream tracking

This is a port, not a fork. The upstream project (`pi-autoresearch`) may gain new features over time. This repo tracks that via:

- **`UPSTREAM.md`** — pinned commit SHA, concept map, porting changelog
- **`scripts/check-upstream.sh`** — run locally to see what's changed upstream
- **Weekly GitHub Action** — opens an issue automatically when upstream has new commits

To check manually:

```bash
bash scripts/check-upstream.sh
```

See [UPSTREAM.md](./UPSTREAM.md) for the full porting guide.

## Session file compatibility

The `autoresearch.md` and `autoresearch.jsonl` formats are kept **identical to upstream** on purpose. Any tooling from the `pi-autoresearch` ecosystem that reads these files will work with sessions produced here, and vice versa.

## License

MIT. The upstream project (`davebcn87/pi-autoresearch`) is also MIT.
