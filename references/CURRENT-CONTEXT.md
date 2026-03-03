# CURRENT-CONTEXT.md — OpenClaw Version-Specific Gotchas

_Auto-updated by pr-ship-update cron. Last updated: 2026-03-03T00:16 UTC (upstream sync)_

---

## Active Version: 2026.3.2 (Released)

### Behavioral Changes (Breaking / Semantics)

- **BREAKING: Node exec approval payloads require `systemRunPlan`.** `host=node` approval requests without that plan are rejected. PRs touching node exec approval flows must include it.
- **BREAKING: Node `system.run` canonical path pinning.** Path-token commands now resolve to canonical executable path (`realpath`) in allowlist and approval flows. Tests asserting token-form argv (e.g. `tr`) must accept canonical paths (e.g. `/usr/bin/tr`).
- **OpenAI Responses WebSocket-first by default:** `openai` provider now uses WebSocket transport by default (`transport: "auto"` with SSE fallback). PRs assuming SSE-only are potentially broken.
- **Discord thread lifecycle overhaul:** Fixed TTL replaced with inactivity-based (`idleHours`, default 24h) plus optional hard `maxAgeHours`. New `/session idle` + `/session max-age` commands.
- **Telegram DM topics:** Per-DM `direct` + topic config (allowlists, `dmPolicy`, `skills`, `systemPrompt`, `requireTopic`). DM topics routed as distinct sessions with topic-aware authorization/debounce.
- **Cron heartbeat light bootstrap:** Opt-in lightweight bootstrap mode (`--light-context` for cron, `agents.*.heartbeat.lightContext` for heartbeat). Skips bootstrap-file injection.
- **Subagent completion events:** Typed `task_completion` internal events replace ad-hoc system-message handoff. PRs touching subagent completion must use new event structure.
- **Sessions/Attachments:** Inline file attachment support for `sessions_spawn` (subagent runtime) with base64/utf8 encoding.
- **ACP/ACPX streaming:** ACPX pinned to `0.1.15`, `final_only` default delivery, reduced tool-event noise.
- **Shell env markers:** `OPENCLAW_SHELL` set across shell-like runtimes (exec, acp, acp-client, tui-local).

### New Gotchas (Things That Now Behave Differently)

- **Browser profile defaults:** `openclaw` profile preferred over `chrome` in headless/no-sandbox environments unless explicit `defaultProfile` configured.
- **Browser act request compatibility:** Legacy flattened `action="act"` params now accepted alongside `request={...}`.
- **Docker sandbox bootstrap hardening:** `OPENCLAW_SANDBOX` now opt-in parsing (`1|true|yes|on`), custom socket paths via `OPENCLAW_DOCKER_SOCKET`, rollback on partial failures.
- **Daemon/systemd in containers:** Missing `systemctl` treated as unavailable (not error) during `is-enabled` checks.
- **Gateway/Container probes:** Built-in `/health`, `/healthz`, `/ready`, `/readyz` endpoints with fallback routing.
- **Security/Prompt spoofing hardening:** Queued runtime events no longer injected into user-role prompt text; spoof markers neutralized.
- **Gateway/WS security:** Plaintext `ws://` loopback-only by default; private-network opt-in via `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1`.
- **Gateway/Subagent TLS pairing:** Local `gateway-client` backend self-connections skip pairing while non-local still requires it.
- **Feishu multi-account + DM routing:** `defaultAccount` outbound routing, `dm:`/`group:` prefix support for `oc_` chat IDs.
- **Tools/Diffs:** New `diffs` plugin tool for read-only diff rendering with canvas/PNG/PDF output.
- **Tools/PDF analysis:** First-class `pdf` tool with native Anthropic/Google support, configurable `pdfModel`/`pdfMaxBytesMb`/`pdfMaxPages`.
- **CLI/Config:** `openclaw config validate` and `openclaw config file` commands.

### High-Risk Modules (Frequently Changed in 2026.3.x)

| Module Prefix | Reason |
|---|---|
| src/telegram/ | DM topics, reply media context, voice fallback chunking, outbound chunking |
| extensions/feishu/ | 15+ fixes: multi-account, docx tools, reactions, media types, rich-text parsing |
| src/agents/ | Subagent completion events, thinking defaults, session status |
| src/security/ | Prompt spoofing hardening, webhook path validation, browser service fail-close |
| src/browser/ | Extension relay reconnect, profile defaults, CDP startup, act compatibility |
| src/cli/ | Config validate, browser timeout, cron list columns |
| apps/android/ | Nodes parity (camera, notifications, contacts, calendar, motion), voice TTS |
| src/infra/ | Container probes, WS security, TLS pairing, sandbox bootstrap |
| src/cron/ | Light bootstrap, announce delivery, lane draining |
| extensions/slack/ | User-token resolution, announce target routing, native commands |

### Pre-PR Checklist Additions (Version-Specific)

- **Node exec PRs:** Must include `systemRunPlan` in approval payloads and accept canonical paths.
- **Browser PRs:** Check profile defaults (openclaw vs chrome), act request format compatibility, CDP startup diagnostics.
- **Feishu PRs:** Multi-account routing, rich-text post parsing, docx API changes, media type classification.
- **Telegram PRs:** DM topic routing, reply media context, outbound chunk splitting.
- **Docker PRs:** Sandbox opt-in parsing, socket paths, health check probes, systemd container detection.
- **Cron PRs:** Light bootstrap mode, announce delivery status, session routing for reminders.
- **Security PRs:** Prompt spoofing neutralization, WS loopback enforcement, webhook path validation.

---

## Recent Behavioral Changes (Rolling Window: Last 4 Versions)

### 2026.3.1 / 2026.3.2

- **OpenAI Responses WS-first default** with SSE fallback and warm-up option.
- **Telegram DM topics** with per-DM config and topic-aware routing.
- **Subagent typed completion events** (`task_completion`) replacing system-message handoff.
- **Node exec canonical path pinning** and `systemRunPlan` requirement.
- **Browser profile defaults** prefer `openclaw` in headless environments.
- **Docker/Container probes** (`/healthz`, `/readyz`) and sandbox bootstrap hardening.
- **Feishu comprehensive overhaul:** Multi-account, docx editing, reactions, rich-text parsing.

### 2026.2.27

- **German locale** support in Web UI.
- **Discord thread lifecycle** inactivity-based controls.
- **Android nodes** camera, device, notifications actions.
- **Security** webhook rate-limit state bounding.

### 2026.2.26

- **Heartbeat `directPolicy` reverted** back to `allow` (was `block` in 2026.2.24-25).
- **Secrets management** workflow (`audit`, `configure`, `apply`, `reload`).
- **OpenAI Codex** WebSocket-first transport.
- **Agent binding CLI** (`openclaw agents bindings/bind/unbind`).

### 2026.2.25

- **ACP thread-bound agents** first-class runtime support.
- **Subagent completion announce** refactored state machine.
- **Slack `parentForkMaxTokens`** cap on parent session token inheritance.
- **Security hardening** across gateway auth, WebSocket, file consent, exec approvals.

---

## Foundational Gotchas (Always Apply)

- **Package manager:** Always use `pnpm` — not `npm`, not `bun`. Build: `pnpm build`. Install: `pnpm install`.
- **Branch force push:** Use `--force-with-lease`, never `--force`.
- **PM2 for gateway:** `pm2 restart openclaw` — never `kill <pid>` or `systemctl restart`.
- **Test files:** Must be co-located with source as `<module>.test.ts` — not in a `__tests__/` dir.
- **No `any` types** in production code paths. TypeScript strictness applies.
- **Channel plugins must remain stateless across reconnects** — no persistent mutable module-level state.
