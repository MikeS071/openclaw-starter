# WORKFLOW_AUTO.md
# Autonomous Operation Protocol — Navi + navi-ops
# Last updated: 2026-02-20

## Purpose
Machine-readable rules governing what Navi may execute autonomously,
what requires Mike's explicit approval, and how the navi-ops CLI
enforces those boundaries at every step.

---

## Classification Rules

Every sprint item is classified into one of three states:

| State        | Meaning                                               | Action               |
|-------------|--------------------------------------------------------|----------------------|
| AUTO         | Safe to execute without approval                      | Execute immediately  |
| NEEDS_USER   | Requires Mike's explicit sign-off before proceeding   | Telegram alert + wait|
| BLOCKED      | Dependencies not resolved or external blocker         | Skip, log reason     |

### AUTO conditions (ALL must be true)
1. Epic status is `in_progress` or `active` in sprint.json
2. Item status is `todo`
3. Item type is `Quick` (Standard/Split always → NEEDS_USER)
4. All dependsOn items are `done` or `delivered`
5. `autoMergeToDev: true`
6. CONFIDENCE_SCORE ≥ 95 after implementation

### NEEDS_USER conditions (ANY is sufficient)
- Epic status is `backlog` (not activated)
- Item type is `Standard` or `Split`
- `autoMergeToDev: false`
- CONFIDENCE_SCORE < 95
- Release deploy (dev → main) — ALWAYS NEEDS_USER, no exceptions
- Item involves: public posting, external comms, secrets/API keys, OAuth changes

---

## Sprint Workflow

### Phases (in order)
```
Phase 0  Pre-flight spec         →  Define assumptions, success criteria, scope
Phase 1  Stories                 →  Break into items if complex (Split type)
Phase 2  Readiness check         →  CONFIDENCE_SCORE ≥ 95 gate
Phase 3  Implementation (build)  →  Code, test, commit
Phase 4  Quality contract        →  Regression + code review pass
Phase 5  Docs gate               →  docs/features/ + docs/technical/ for items with docsRequired=true
Prod     Release                 →  Mike approval → navi-ops release check → ALL CLEAR → merge main
```

### Phase 5 Docs Gate
- Only items in sprint.json with `docsRequired: true` AND `status: "done"` are checked.
- Each such item must have `docSlug` set — the filename (without .md) in docs/features/ and docs/technical/.
- Gate enforced by: `navi-ops release check` (Gate 2) and `navi-ops release docs`.
- Historical git commits are NOT scanned — opt-in only.

### CONFIDENCE_SCORE threshold
- ≥ 95 → auto-merge to dev permitted (if all other AUTO conditions met)
- < 95 → NEEDS_USER, send score breakdown to Mike via Telegram

---

## Hard Rules (never override)

1. **NEVER push or merge to main without Mike's explicit "yes, merge to main".**
   Not for hotfixes. Not for CONFIDENCE_SCORE 100. Not for "trivial" changes.
2. **NEVER auto-post to social media.** All tweets/LinkedIn need Mike approval.
3. **NEVER exfiltrate private data** (API keys, personal info, DB contents).
4. **NEVER re-enable mission-control.service** (systemd) — permanently disabled.
5. **NEVER skip Phase 5 docs gate** without a written reason in the audit log.
6. **NEVER use `pkill -f next`** — kills the exec shell. Always kill by PID file.
7. **NEVER push directly to main** — pre-push hook blocks it; don't bypass.
8. **Max 2 research note emails/day** to mszalinski@australiansuper.com (crons only).

---

## navi-ops Autonomous Loop (`navi-ops run`)

### Trigger
- Every 30 minutes via OpenClaw cron (cron ID: `276cc314`)
- Manual: `navi-ops run` / `navi-ops run --dry-run`

### Execution order
1. Load sprint.json
2. Classify all items → AUTO / NEEDS_USER / BLOCKED
3. For AUTO items: spawn sub-agent via `openclaw agent --agent <role> --message <msg>`
4. For NEEDS_USER items: send Telegram alert with item title + reason
5. Log all actions to `navi-ops.log`
6. On completion: run `navi-ops status` → append summary to log

### Sub-agent dispatch (parallel)
- Dispatcher: `http://127.0.0.1:7070`
- Independent items run concurrently (no sequential waiting)
- Each sub-agent reports back via sessions_spawn announce

### BLOCKED handling
- Log the blocker reason
- Skip silently — no Telegram noise for BLOCKED items unless explicitly requested

---

## Alert Conditions (Telegram → chat ID 1556514337)

| Condition                          | Severity | Alert text                                      |
|------------------------------------|----------|-------------------------------------------------|
| Prod returns non-200               | CRITICAL | "URGENT: prod is {code} — check CF tunnel"     |
| CF tunnel process not running      | CRITICAL | "URGENT: CF tunnel down — restart cloudflared" |
| Regression test failure            | HIGH     | "Regression failing — fix before deploy"        |
| Gateway RSS > 1000 MB              | HIGH     | "Gateway memory leak risk — RSS {value} MB"    |
| Available RAM < 400 MB             | HIGH     | "Host RAM critical — {value} MB free"          |
| NEEDS_USER item ready              | INFO     | Item title + classification reason              |
| CONFIDENCE_SCORE < 95              | INFO     | Score breakdown + story ID                     |

---

## Agent Roles & Models

| Role              | Model           | Mode        | When invoked                          |
|-------------------|-----------------|-------------|---------------------------------------|
| architect         | sonnet          | Research    | Split stories — before planner        |
| planner           | sonnet          | Research    | Standard/Split — spec creation        |
| code-agent        | gpt-5.3-codex   | Development | All implementation work               |
| tdd-guide         | gpt-5.3-codex   | Development | Test writing + red-green-refactor     |
| code-reviewer     | sonnet          | Review      | After implementation, before merge    |
| security-reviewer | sonnet          | Review      | Any auth/tenant/file/input changes    |
| build-error-resolver | gpt-5.3-codex | Development | Build failures (max 5 runs)          |
| doc-updater       | opus            | Development | Phase 5 gaps — auto-spawned           |
| e2e-runner        | sonnet          | Development | regression-test.sh + smoke tests      |
| refactor-cleaner  | gpt-5.3-codex   | Development | Cleanup pass after feature work       |

---

## Key Paths

| Resource              | Path / Value                                              |
|-----------------------|-----------------------------------------------------------|
| sprint.json           | workflow/sprint.json                                      |
| navi-ops binary       | /home/openclaw/.local/bin/navi-ops                        |
| navi-ops log          | /home/openclaw/.openclaw/workspace/navi-ops.log           |
| MC repo               | /home/openclaw/projects/openclaw-mission-control/         |
| MC dev URL            | http://127.0.0.1:3003                                     |
| MC prod URL           | https://archonhq.ai                                       |
| pre-release-check     | scripts/pre-release-check.sh                              |
| regression-test       | scripts/regression-test.sh                                |
| Telegram chat ID      | 1556514337                                                |
| Dispatcher            | http://127.0.0.1:7070                                     |
