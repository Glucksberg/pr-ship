# CURRENT-CONTEXT.md — OpenClaw Version-Specific Gotchas

_Auto-updated by fork-manager changelog-watch. Last updated: 2026-02-27T10:40 UTC (upstream sync)_

---

## Active Version: 2026.2.26 (Released)

### Behavioral Changes (Breaking / Semantics)

- **Heartbeat directPolicy default flipped back to `allow`:** After `2026.2.24` set it to `block`, `2026.2.25` reverts the default to `allow`. Anyone who migrated to `block` must explicitly set `agents.defaults.heartbeat.directPolicy: "block"` or per-agent override. PRs touching heartbeat delivery must account for this.
- **`openclaw onboard --reset` scope changed:** Default scope is now `config+creds+sessions` (workspace deletion requires `--reset-scope full`). PRs touching onboarding flows or CLI `--reset` must update documentation and tests.
- **Secrets management:** New `openclaw secrets` workflow (`audit`, `configure`, `apply`, `reload`) with runtime snapshot activation. Config files referencing auth fields may now be validated through `secrets apply` with stricter target-path validation.
- **OpenAI Codex transport default:** `openai-codex` is now WebSocket-first by default (`transport: "auto"` with SSE fallback). PRs that assume SSE-only Codex transport are now potentially broken.
- **Discord thread lifecycle:** Replaced fixed TTL with inactivity-based (`idleHours`, default 24h) plus optional hard `maxAgeHours` controls. New `/session idle` and `/session max-age` commands added.

### New Gotchas (Things That Now Behave Differently)

- **Agent binding CLI:** New `openclaw agents bindings/bind/unbind` commands for account-scoped route management. PRs that modify agent routing or account binding must not conflict with channel-only to account-scoped upgrade paths.
- **Session parentForkMaxTokens:** Slack thread session parent inheritance now capped at `100000` tokens (`session.parentForkMaxTokens`; `0` disables). PRs touching Slack session context sizing should know this new config knob.
- **ACP thread-bound agents:** ACP agents are now first-class thread-session runtimes. PRs touching subagent/session spawning must handle new `acp` runtime paths.
- **`plugins.entries.*` unknown keys:** Now startup warnings (ignored stale keys) instead of hard validation failures. PRs that rely on strict plugin entry validation may see behavior change.
- **Auth-profiles alias normalization:** `mode -> type` and `apiKey -> key` now auto-normalized. PRs touching auth-profile reading must not double-apply the rename.
- **Model `@profile` suffix parsing:** Now centralized; `@` only treated as profile separator after final `/`. Model IDs like `openai/@cf/...` no longer broken. PRs touching model parsing must use the new centralized parser.
- **`openai-codex-responses`:** Now a valid `ModelApi` type in config schema and TypeScript union. PRs that enumerate ModelApi values must include it.
- **Cron isolated routing session keys:** `agent:*` keys no longer double-prefixed. PRs touching cron delivery or isolated routing must not re-add a prefix.
- **Cron lane draining:** New `draining` flag reset guarantees + new queue reject behavior during gateway restart drain windows. PRs touching queue management or restart flows must handle the new drain-reject error path.
- **Telegram DM allowlist inheritance:** `dmPolicy: "allowlist"` now enforced with effective account-plus-parent config across all account-capable channels. `openclaw doctor --fix` can restore missing `allowFrom` entries.
- **Queue recovery backoff:** Failed sends now persist `lastAttemptAt` and defer recovery retries until `lastAttemptAt + backoff` window, preventing retry starvation.

### High-Risk Modules (Frequently Changed in 2026.2.25-26)

| Module Prefix | Reason |
|---|---|
| src/security/ | 15+ security fixes in both versions: SSRF, symlinks, hardlinks, exec approvals, pairing |
| src/telegram/ | Multiple webhook, streaming, typing, spoiler, native-commands fixes |
| src/agents/ | Compaction safety, model fallback, config merge, tools normalization |
| src/config/ | Auth-profiles alias, plugin entries validation, model API schema |
| src/cli/ | Gateway CLI, openclaw agents, openclaw secrets, openclaw onboard, openclaw sessions |
| extensions/bluebubbles/ | SSRF allowlist, monitor processing |
| extensions/mattermost/ | Monitor auth |
| src/plugins/ | Path-safety hardening, channel HTTP auth normalization |
| src/infra/path-guards.ts | Symlink/hardlink boundary hardening |
| src/queue/ | Drain/cron reliability overhaul |

### Pre-PR Checklist Additions (Version-Specific)

- **Security PRs:** If your PR touches path handling, symlinks, exec approvals, or auth — check against the 15+ security fixes in 2026.2.25-26. Confirm your change does not regress the stricter boundary checks.
- **Typing indicator PRs:** 6+ typing indicator fixes landed in 2026.2.25-26 across Telegram, Discord, Slack, and cross-channel paths. Ensure your PR does not reintroduce leakage or stuck-indicator bugs.
- **Model/Auth PRs:** Auth-profile alias normalization and model API enum changes affect config validation. Regenerate config schema types if you touched `types.models.ts` or `zod-schema.core.ts`.
- **Cron/Queue PRs:** New drain window reject semantics and session key prefix invariants. Confirm your cron change does not assume pre-drain-fix queue accept behavior.
- **Telegram webhook PRs:** Webhook startup now pre-initializes bots with callback-mode JSON. PRs touching webhook processing must preserve this path.

---

## Recent Behavioral Changes (Rolling Window: Last 4 Versions)

### 2026.2.25

- **Heartbeat `directPolicy` introduced:** New config to control DM delivery behavior (later default reverted in 2026.2.26).
- **ACP thread-bound agents:** First-class runtime support for ACP agents in thread sessions.
- **Subagent completion announce dispatch:** Refactored into explicit state machine with proper cleanup.
- **Slack `parentForkMaxTokens`:** Cap on parent session token inheritance for thread sessions.
- **Security hardening:** Gateway auth, WebSocket origin checks, trusted proxy restrictions, file consent binding, exec approvals hardening, workspace FS hardlinks blocked.

### 2026.2.24

- **Auto-reply abort shortcuts:** Expanded multilingual stop phrases (`stop openclaw`, `please stop`, etc.) with trailing punctuation support.
- **Android onboarding:** Native four-step flow, five-tab shell (Connect, Chat, Voice, Screen, Settings).
- **Heartbeat delivery breaking change:** Blocks direct/DM targets by default (reverted in 2026.2.25).
- **Security sandbox breaking change:** Blocks Docker `network: "container:<id>"` by default (opt-in via `dangerouslyAllowContainerNamespaceJoin`).
- **Talk/Gateway config:** Provider-agnostic Talk configuration with gateway metadata exposure.

---

## Foundational Gotchas (Always Apply)

- **Package manager:** Always use `pnpm` — not `npm`, not `bun`. Build: `pnpm build`. Install: `pnpm install`.
- **Branch force push:** Use `--force-with-lease`, never `--force`.
- **PM2 for gateway:** `pm2 restart openclaw` — never `kill <pid>` or `systemctl restart`.
- **Test files:** Must be co-located with source as `<module>.test.ts` — not in a `__tests__/` dir.
- **No `any` types** in production code paths. TypeScript strictness applies.
- **Channel plugins must remain stateless across reconnects** — no persistent mutable module-level state.
