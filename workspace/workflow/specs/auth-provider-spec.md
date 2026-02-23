# Pre-flight Spec — AiPipe Multi-Tenant Auth + Provider Onboarding

**Epic ID:** epic-auth-provider  
**Type:** Split (6 stories, architect → planner → code-agent)  
**Priority:** High  
**Effort:** ~26h across 6 stories  
**Risk:** High (per-tenant data isolation, key storage, AiPipe server surgery)  
**Date:** 2026-02-20  
**Approved by:** mike

---

## Assumptions & Ambiguity

1. AiPipe currently uses **global env-var keys** (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `XAI_API_KEY`). These remain as **host-operator fallback** — they are not removed.
2. Per-tenant keys **override** global keys when present. If a tenant has no key for a provider, that provider is unavailable for that tenant.
3. `X-Tenant-ID` header is injected by MC on every proxy request (MC is the only caller of AiPipe — no unauthenticated external access to AiPipe).
4. AiPipe is a **single binary on the host** — it does not know about MC's auth/session system. Tenant identity flows in via header only.
5. AiPipe admin endpoints (`/v1/tenants/...`) are **internal only** — bound to localhost, no public exposure. MC calls them server-side.
6. SQLite is the right store for per-tenant keys + stats: structured queries for aggregation, no extra infra, fits in `~/.config/aipipe/aipipe.db`.
7. Stats reset on service restart is **acceptable for MVP** — rolling window in memory, periodic flush to SQLite every 60s.
8. Google Gemini uses the **Google AI Studio OpenAI-compat endpoint** (`generativelanguage.googleapis.com/v1beta/openai`) — API key only, no OAuth for MVP.
9. New wizard step 6 (navi-ops agent roles) stores role→model mapping in `tenantSettings.agentRoles` in MC DB.
10. Step 5 (general model preferences) remains unchanged — it covers non-navi-ops model choices.
11. Model dropdown options in step 6 are **statically defined** — we list all models across all 6 providers (not dynamically filtered by what the tenant configured). Dynamic filtering is a future improvement.
12. Wizard is `"Step X of 8"` after this change (7→8 steps total).
13. `docsRequired: true` — user-facing feature. Docs gate applies.

---

## Success Criteria

- [ ] AiPipe accepts `X-Tenant-ID` header; routes using tenant's stored keys; falls back to global env-var keys
- [ ] AiPipe tracks stats per tenant; `GET /v1/tenants/{id}/stats` returns isolated per-tenant data
- [ ] AiPipe supports 6 providers: OpenAI, Anthropic, OpenRouter, MiniMax, Kimi (Moonshot), Gemini
- [ ] MC admin endpoints (`POST /v1/tenants/{id}/providers`) are called on wizard save — keys synced to AiPipe store
- [ ] Wizard step 3 shows all 6 providers with key inputs and live validation
- [ ] Wizard new step 6 shows 10 navi-ops roles with model dropdowns, pre-filled with current defaults
- [ ] `tenantSettings.agentRoles` in MC DB stores the role→model JSON on save
- [ ] AiPipe dashboard widget shows per-tenant stats (not aggregate)
- [ ] Regression suite passes 80+ tests (no regressions)
- [ ] `navi-ops release check` Gate 2 passes with `auth-provider` docs

---

## Scope

### What we ARE building
- AiPipe: `internal/tenant/` package (SQLite store + manager)
- AiPipe: 4 new provider files (OpenRouter, MiniMax, Kimi, Gemini)
- AiPipe: per-tenant routing in `server.go` + `handleProxy`
- AiPipe: tenant admin HTTP endpoints
- AiPipe: per-tenant stats tracking
- MC: wizard step 3 updated (6 providers)
- MC: wizard step 6 added (navi-ops role model assignment)
- MC: wizard count updated 7→8
- MC: `tenantSettings` schema extended with `agentRoles`
- MC: proxy routes inject `X-Tenant-ID`
- MC: key sync API call to AiPipe on wizard save
- MC: AiPipe widget updated to call per-tenant stats endpoint
- Tests + regression
- Phase 5 docs

### What we are NOT building
- OAuth / PKCE flows for any provider (API key only)
- Dynamic model dropdown based on configured providers
- AiPipe multi-instance / HA deployment
- Tenant management UI (add/remove tenants via dashboard) — admin API only
- AiPipe exposed on public network — localhost only
- Key rotation or audit log

---

## Architecture

### AiPipe Token Store (SQLite)

**File:** `~/.config/aipipe/aipipe.db`

```sql
CREATE TABLE tenants (
  id         TEXT PRIMARY KEY,   -- MC tenant ID (e.g. "1")
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE provider_keys (
  tenant_id  TEXT NOT NULL,
  provider   TEXT NOT NULL,      -- "openai" | "anthropic" | "openrouter" | "minimax" | "kimi" | "gemini"
  api_key    TEXT NOT NULL,      -- stored in plaintext (SQLite file is mode 600)
  added_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (tenant_id, provider),
  FOREIGN KEY (tenant_id) REFERENCES tenants(id)
);

CREATE TABLE stats (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id  TEXT NOT NULL,
  provider   TEXT NOT NULL,
  model      TEXT NOT NULL,
  requests   INTEGER DEFAULT 0,
  in_tokens  INTEGER DEFAULT 0,
  out_tokens INTEGER DEFAULT 0,
  cost_usd   REAL DEFAULT 0,
  recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

DB file permissions: `0600` — created by AiPipe on first start.

### AiPipe Package Structure (new + modified)

```
internal/
  tenant/
    store.go      — SQLite CRUD: upsert/get/delete keys; write stats; query per-tenant stats
    manager.go    — in-memory cache (TTL 60s); resolve keys for request; background flush
  provider/
    openrouter.go — OpenAI-compat, base URL: api.openrouter.ai/v1
    minimax.go    — OpenAI-compat, base URL: api.minimax.chat/v1
    kimi.go       — OpenAI-compat, base URL: api.moonshot.cn/v1
    gemini.go     — OpenAI-compat, base URL: generativelanguage.googleapis.com/v1beta/openai
  app/
    server.go     — extract X-Tenant-ID; resolve tenant keys; pass to provider; record per-tenant stats
```

New provider type constants in `internal/types/types.go`:
- `ProviderOpenRouter = "openrouter"`
- `ProviderMiniMax = "minimax"`
- `ProviderKimi = "kimi"`
- `ProviderGemini = "gemini"`

### AiPipe Admin Endpoints (new, internal only)

```
POST   /v1/tenants/{id}/providers         — upsert provider key for tenant
DELETE /v1/tenants/{id}/providers/{name}  — remove provider key
GET    /v1/tenants/{id}/stats             — per-tenant stats snapshot
GET    /v1/tenants                        — list all tenant IDs (admin)
```

All admin endpoints require `X-Admin-Secret` header (value = `AIPIPE_ADMIN_SECRET` env var, stored in `~/.config/aipipe/env`).

### Request Flow (per-tenant)

```
MC API route /api/aipipe/proxy/chat
  → injects X-Tenant-ID: {tenantId}
  → injects X-Admin-Secret is NOT on proxy routes (user-facing path)
  → AiPipe handleProxy extracts X-Tenant-ID
  → manager.ResolveKeys(tenantId) → returns map[provider]apiKey
  → registry filtered to providers with a key for this tenant
  → PickFor as before → upstream call with tenant key
  → stats.RecordTenantCall(tenantId, provider, model, ...)
```

Fallback chain: tenant key → global env-var key → skip provider.

### MC Settings Schema Extension

`tenantSettings` JSON (existing `settings` JSONB column in `tenants` table):

```typescript
type AgentRoles = {
  architect?: string;
  planner?: string;
  codeAgent?: string;
  tddGuide?: string;
  codeReviewer?: string;
  securityReviewer?: string;
  buildErrorResolver?: string;
  docUpdater?: string;
  e2eRunner?: string;
  refactorCleaner?: string;
};

// Added to existing SettingsPayload:
agentRoles?: AgentRoles;

// Added to existing SettingsPayload (step 3 extended):
openrouterKey?: string;
minimaxKey?: string;
kimiKey?: string;
geminiKey?: string;
```

### Wizard Step 3 (updated — 6 providers)

| Provider | Placeholder | Link |
|---|---|---|
| OpenAI | `sk-proj-...` | platform.openai.com |
| Anthropic | `sk-ant-...` | console.anthropic.com |
| OpenRouter | `sk-or-...` | openrouter.ai/keys |
| MiniMax | `...` | api.minimax.chat |
| Kimi (Moonshot) | `...` | platform.moonshot.cn |
| Gemini | `AIza...` | aistudio.google.com |

All optional. At least 1 required to proceed (same as current behaviour).

On save: keys posted to `tenantSettings` AND synced to AiPipe via `POST /v1/tenants/{id}/providers`.

### Wizard Step 6 (new — navi-ops agent roles)

Title: `"Configure your AI team 🤖"`
Subtitle: `"Each agent role has a smart default — override if you want a different model."`

10 role pickers using the existing `ModelPicker` component. Pre-filled defaults:

```typescript
const AGENT_ROLE_DEFAULTS = {
  architect:           'claude-sonnet-4-6',
  planner:             'claude-sonnet-4-6',
  codeAgent:           'gpt-5.3-codex',
  tddGuide:            'gpt-5.3-codex',
  codeReviewer:        'claude-opus-4',
  securityReviewer:    'claude-sonnet-4-6',
  buildErrorResolver:  'gpt-5.3-codex',
  docUpdater:          'claude-opus-4',
  e2eRunner:           'claude-sonnet-4-6',
  refactorCleaner:     'gpt-5.3-codex',
};
```

Model options (static list across all 6 providers):

```typescript
const ALL_MODELS = [
  // Anthropic
  'claude-haiku-3', 'claude-sonnet-4-6', 'claude-opus-4',
  // OpenAI
  'gpt-4o-mini', 'gpt-4o', 'gpt-5.1-codex', 'gpt-5.3-codex',
  // OpenRouter (passthrough — user can type custom model ID)
  'openrouter/auto',
  // MiniMax
  'minimax/abab6.5s-chat',
  // Kimi
  'moonshot-v1-8k', 'moonshot-v1-32k',
  // Gemini
  'gemini-2.0-flash', 'gemini-2.0-pro',
];
```

Save → `POST /api/settings` with `{ settings: { agentRoles: {...} }, merge: true }`.

---

## Story Breakdown

### auth-1 — AiPipe: SQLite per-tenant store + admin endpoints
**Type:** Standard | **Effort:** 5h | **Risk:** Medium  
**Repo:** `/home/openclaw/projects/AiPipe/`  
**Agent:** code-agent (gpt-5.3-codex)  
**Files:**
- `internal/tenant/store.go` (~200 lines)
- `internal/tenant/manager.go` (~120 lines)
- `internal/app/admin.go` — admin route handlers (~100 lines)
- `internal/config/config.go` — add `DBPath`, `AdminSecret` fields (~+20 lines)
- `main.go` — init DB on startup (~+10 lines)

**Success criteria:**
- SQLite DB created at `~/.config/aipipe/aipipe.db` with correct schema on first run
- `POST /v1/tenants/{id}/providers` upserts a key; `GET /v1/tenants/{id}/stats` returns empty snapshot
- `X-Admin-Secret` header required; returns 401 without it
- `store_test.go`: upsert, get, delete, list — 8 tests pass, race-clean
- DB file mode is 0600

**Can parallelize with:** auth-2 (different packages, no shared code)

---

### auth-2 — AiPipe: 4 new providers + per-tenant routing
**Type:** Standard | **Effort:** 5.5h | **Risk:** High (server.go surgery)  
**Repo:** `/home/openclaw/projects/AiPipe/`  
**Agent:** code-agent (gpt-5.3-codex)  
**Files:**
- `internal/types/types.go` — 4 new ProviderXxx constants (~+8 lines)
- `internal/model/models.go` — add model configs for new providers (~+40 lines)
- `internal/provider/openrouter.go` (~60 lines)
- `internal/provider/minimax.go` (~60 lines)
- `internal/provider/kimi.go` (~60 lines)
- `internal/provider/gemini.go` (~60 lines)
- `internal/app/server.go` — extract `X-Tenant-ID`; resolve per-tenant keys; filter registry; record per-tenant stats (~+80 lines, surgical)
- `internal/app/server.go` `enabledModelConfigs()` — extend for 4 new providers

**Success criteria:**
- `OPENROUTER_API_KEY`, `MINIMAX_API_KEY`, `KIMI_API_KEY`, `GEMINI_API_KEY` env vars respected globally
- Per-tenant: if tenant has a key for a provider, that provider is enabled for that request
- Fallback: tenant key → env var key → skip provider
- `X-Tenant-ID` missing → use global keys only (host-operator mode, backward compatible)
- Unit tests for each new provider `buildPayload` + `parseResponse`: 4×4=16 tests pass
- Race-clean under `go test -race`

**Depends on:** auth-1 (needs tenant.manager.ResolveKeys)

---

### auth-3 — MC: wizard step 3 update + new step 6 (navi-ops roles)
**Type:** Standard | **Effort:** 4h | **Risk:** Low  
**Repo:** `/home/openclaw/projects/openclaw-mission-control/`  
**Agent:** code-agent (gpt-5.3-codex)  
**Files:**
- `src/app/dashboard/connect/page.tsx` — step 3 add 4 new providers; step 6 new; renumber 6→7, 7→8; update `WizardStep` type; update summary checklist (~+150 lines, surgical)
- `src/app/api/settings/route.ts` — handle new keys + `agentRoles` in PATCH (~+20 lines)

**Success criteria:**
- Step 3 shows all 6 providers; saves all keys to settings on "Save & continue"
- New step 6 renders 10 `ModelPicker` components; pre-fills from `AGENT_ROLE_DEFAULTS`; loads saved values from settings on mount
- Step 6 "Save & continue" → saves `agentRoles` to `tenantSettings`
- `progressLabel` shows "Step X of 8" throughout
- Step 7 summary card reflects all 8 steps
- Existing steps 1-5 and 7 unchanged (no regressions)
- Manual smoke test: complete wizard end-to-end, check settings API returns `agentRoles`

**Can parallelize with:** auth-1, auth-2 (MC changes are independent of AiPipe Go changes)

---

### auth-4 — MC↔AiPipe: key sync + per-tenant stats widget
**Type:** Standard | **Effort:** 2.5h | **Risk:** Medium  
**Repo:** `/home/openclaw/projects/openclaw-mission-control/`  
**Agent:** code-agent (gpt-5.3-codex)  
**Files:**
- `src/lib/aipipe.ts` — add `aipipeSyncTenantKeys(tenantId, keys)` (calls `POST /v1/tenants/{id}/providers`); add `aipipeTenantStats(tenantId)` (calls `GET /v1/tenants/{id}/stats`) (~+40 lines)
- `src/app/api/settings/route.ts` — on provider key save, call `aipipeSyncTenantKeys` server-side (~+15 lines)
- `src/app/api/aipipe/stats/route.ts` — pass `tenantId` from session to `aipipeTenantStats` (~+10 lines)
- `src/app/api/aipipe/proxy/chat/route.ts` — inject `X-Tenant-ID` header (~+5 lines)
- `src/app/api/aipipe/proxy/messages/route.ts` — inject `X-Tenant-ID` header (~+5 lines)
- `src/components/AiPipeWidget.tsx` — no UI change needed; stats endpoint now returns per-tenant data automatically

**Success criteria:**
- Saving keys in wizard step 3 triggers sync to AiPipe; `GET /v1/tenants/{id}/stats` returns data after next proxied request
- AiPipe widget shows per-tenant stats (not aggregate)
- Proxy routes include `X-Tenant-ID: {tenantId}` on every forwarded call
- Sync failure is non-fatal (log + continue; keys still saved to MC DB)
- `AIPIPE_ADMIN_SECRET` in `.env.local`; value from `pass apis/aipipe-admin-secret`

**Depends on:** auth-1, auth-2, auth-3

---

### auth-5 — Tests + regression suite update
**Type:** Standard | **Effort:** 5.5h | **Risk:** Low  
**Repos:** Both  
**Agent:** tdd-guide (gpt-5.3-codex)  
**Files:**
- `AiPipe/Server/internal/tenant/store_test.go` (~150 lines)
- `AiPipe/Server/internal/tenant/manager_test.go` (~80 lines)
- `AiPipe/Server/internal/app/admin_test.go` (~80 lines)
- `scripts/regression-test.sh` — section 16: AiPipe per-tenant endpoints (6 new checks)

**New regression checks (section 16):**
1. `GET /api/aipipe/health` returns 200 (already in section 15 — skip duplicate)
2. `POST /v1/tenants/test/providers` without admin secret returns 401
3. `POST /v1/tenants/test/providers` with admin secret + valid payload returns 200
4. `GET /v1/tenants/test/stats` with admin secret returns JSON with `requests` field
5. `GET /api/aipipe/stats` via MC proxy returns 200 (already exists — verify per-tenant shape)
6. Wizard page at `/dashboard/connect` still returns 200 (already in section 3)

**Success criteria:**
- All AiPipe Go tests pass: `go test ./... -race` — 0 failures
- Regression suite: 80 → 86 tests (6 new), all pass
- `navi-ops release check` reports ALL CLEAR

**Depends on:** auth-1 through auth-4

---

### auth-6 — Phase 5 docs
**Type:** Standard | **Effort:** 3h | **Risk:** None  
**Repo:** `/home/openclaw/projects/openclaw-mission-control/`  
**Agent:** doc-updater (opus)  
**Files:**
- `docs/features/auth-provider.md` — user-facing: how to add providers, what each one does, wizard walkthrough
- `docs/technical/auth-provider.md` — per-tenant SQLite schema, admin endpoints, key sync flow, fallback chain, new provider base URLs
- Update `docs/features/aipipe-integration.md` — note per-tenant stats, link to auth-provider doc

**Success criteria:**
- Both docs exist and cover all features built in auth-1 through auth-4
- `navi-ops release docs` passes without gaps
- Roadmap updated: move `auth-provider` to Delivered section

**Depends on:** auth-5 (write docs after implementation is stable)

---

## Implementation Steps

| Step | Action | Why | Risk |
|---|---|---|---|
| 1 | auth-1: SQLite store + admin endpoints in AiPipe | Foundation for all per-tenant work | Medium — new DB dependency |
| 2 | auth-2: New providers + per-tenant routing (parallel with auth-3) | Core routing change | High — server.go surgery; validate backward compat |
| 3 | auth-3: Wizard updates (parallel with 1+2) | MC-only, no AiPipe dep | Low |
| 4 | auth-4: Key sync + per-tenant stats | Wires MC→AiPipe | Medium — depends on 1+2+3 all done |
| 5 | auth-5: Tests + regression | Gate before merge | Low |
| 6 | auth-6: Docs | Phase 5 gate | None |

Steps 1, 2, 3 can run in parallel.  
Step 4 depends on 1+2+3.  
Steps 5+6 depend on 4.

---

## Testing Strategy

### AiPipe (Go)
- `go test ./... -race -count=1` — all packages
- Focus: `internal/tenant/store_test.go` — SQLite CRUD correctness + concurrency
- Focus: `internal/app/` — admin endpoint auth, per-tenant key resolution
- Focus: provider tests — each new provider's request/response translation

### MC (TypeScript)
- Wizard: manual smoke test (complete 8-step wizard, verify all settings saved)
- Stats widget: verify `X-Tenant-ID` flows from session through to AiPipe
- `scripts/regression-test.sh` gate (86 tests)

### Red Flags (stop and raise to Mike)
- Any cross-tenant key leak: tenant A's request using tenant B's key
- AiPipe DB file created with permissions > 0600
- Admin endpoints responding without `X-Admin-Secret`
- Wizard step count mismatch between UI and summary card
- Any test failure in existing sections 1–15 (regression)

---

## Secrets Required (before auth-4 build)

```bash
# Generate and store AiPipe admin secret
openssl rand -hex 32 | gpg --batch --yes -e -r navi@openclaw.local \
  -o ~/.password-store/apis/aipipe-admin-secret.gpg

# Add to AiPipe env file
echo "AIPIPE_ADMIN_SECRET=$(pass show apis/aipipe-admin-secret)" \
  >> ~/.config/aipipe/env

# Add to MC .env.local
echo "AIPIPE_ADMIN_SECRET=$(pass show apis/aipipe-admin-secret)" \
  >> /home/openclaw/projects/openclaw-mission-control/.env.local
```

---

## Definition of Done

- [ ] auth-1: SQLite store + admin endpoints — `go test ./... -race` pass, DB created at first run
- [ ] auth-2: 4 new providers + per-tenant routing — backward compat verified (no X-Tenant-ID = global keys)
- [ ] auth-3: Wizard 8 steps, all role defaults pre-filled, `agentRoles` saved to DB
- [ ] auth-4: Key sync on wizard save, `X-Tenant-ID` on all proxy requests, widget shows per-tenant stats
- [ ] auth-5: 86/86 regression tests pass, `navi-ops release check` ALL CLEAR
- [ ] auth-6: Both docs written, roadmap updated
- [ ] AiPipe service restarted with new build — `systemctl --user restart aipipe` ✅
- [ ] Merged to dev — awaiting Mike "merge to main"
