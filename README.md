# pr-ship

Pre-ship risk report skill for [OpenClaw](https://github.com/openclaw/openclaw) pull requests. Dynamically explores the codebase to assess module risk, blast radius, and version-specific gotchas. Scores each finding by severity.

## Install

```bash
clawhub install pr-ship
```

## Update

```bash
clawhub update pr-ship
```

## How it works

1. Diffs your current branch against `main`
2. Classifies changed modules by risk tier
3. Runs dynamic exploration (grep, find, git) per module
4. Produces a structured risk report with evidence-backed findings

See [SKILL.md](SKILL.md) for the full workflow and report format.

## Provenance

- **Maintainer:** Markus Glucksberg ([@Glucksberg](https://github.com/Glucksberg))
- **Published on:** [ClawHub](https://clawhub.com/skills/pr-ship)
- **Update mechanism:** Daily cron checks OpenClaw upstream `CHANGELOG.md`. When changes are detected, `CURRENT-CONTEXT.md` metadata is updated, pushed to this repo, and published to ClawHub.
- **Verification:** This GitHub repo is canonical. The ClawHub version should always match GitHub HEAD.

## License

MIT
