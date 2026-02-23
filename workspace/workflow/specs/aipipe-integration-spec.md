# Pre-flight Spec — AiPipe Integration + Connection Wizard

**Epic ID:** epic-aipipe  
**Type:** Split (architect → planner → code-agent)  
**Priority:** Critical  
**Effort:** ~2 sprints  
**Risk:** Medium (new service deployment + multi-step UI)  
**Date:** 2026-02-20

---

## Assumptions & Ambiguity

1. AiPipe server code is **already complete and tested** in `/home/openclaw/projects/AiPipe/Server/` — we are NOT rewriting it.
2. The sprint covers: deploy AiPipe as a managed service + MC settings integration + connection wizard UI.
3. AiPipe runs on the same host as MC (`ocprd-sgp1-01`), port `:8080` (configurable via `AIPIPE_LISTEN_ADDR`).
4. MC connects to AiPipe as a sidecar — tenants point their OpenClaw gateway through AiPipe.
5. The connection wizard is the primary onboarding UX: connect OpenClaw gateway → route through AiPipe → see savings.
6. Per-tenant API keys are out of MVP scope (AiPipe uses server-side keys for now — single tenant).
7. AiPipe stats are surfaced in MC dashboard (new widget), not a separate UI.
8. `docsRequired: true` — this is a major user-facing feature.

---

## Success Criteria

- [ ] AiPipe binary built and running as systemd service on ocprd-sgp1-01
- [ ] MC settings page has AiPipe configuration section (URL + connection test)
- [ ] `/api/aipipe/stats` route in MC proxies to AiPipe `/v1/stats`
- [ ] `/api/aipipe/proxy` route in MC forwards LLM requests through AiPipe (used by OpenClaw gateway clients)
- [ ] Dashboard has AiPipe stats widget: requests routed, total cost saved, cache hit %, top provider
- [ ] Connection wizard (4 steps) fully functional at `/dashboard/connect`
- [ ] Regression suite extended with AiPipe health check + stats endpoint checks
- [ ] `navi-ops release check` Gate 2 passes with `aipipe-integration` docs

---

## Scope

### Story 1 — AiPipe service deployment (Quick, ~1h)
- Build binary: `cd /home/openclaw/projects/AiPipe/Server && go build -o /home/openclaw/.local/bin/aipipe ./cmd/aipipe`
- Create systemd service: `aipipe.service` — runs as `openclaw` user, restarts on failure
- Env: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `XAI_API_KEY` from pass store (injected via `EnvironmentFile`)
- Expose on `127.0.0.1:8080` only (not public — MC proxies it)
- Health check: `curl http://127.0.0.1:8080/healthz`
- Add to HEARTBEAT.md check list

### Story 2 — MC API: AiPipe proxy routes (Standard, ~2h)
New routes in MC:

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/api/aipipe/stats` | Bearer/session | Proxy to AiPipe `/v1/stats` |
| POST | `/api/aipipe/proxy/chat` | Bearer/session | Forward to AiPipe `/v1/chat/completions` |
| POST | `/api/aipipe/proxy/messages` | Bearer/session | Forward to AiPipe `/v1/messages` |
| GET | `/api/aipipe/health` | Bearer/session | Proxy to AiPipe `/healthz` |

AiPipe URL read from: env `AIPIPE_URL` (default `http://127.0.0.1:8080`).
All routes gated behind `resolveTenantId()`. Add Zod to all body-accepting routes.

### Story 3 — MC Dashboard: AiPipe stats widget (Standard, ~3h)
New widget on main dashboard (`/dashboard`):
- **Requests routed**: total from stats
- **Cost saved**: estimate based on average savings vs. direct Sonnet/GPT-4o pricing
- **Cache hit %**: from stats.runtime.cache_hits / total
- **Top provider today**: provider with most requests
- **Model breakdown**: mini table of provider/model/requests/cost

Data source: `/api/aipipe/stats` — poll every 60s (same pattern as heartbeat).
Show "AiPipe not connected" state if API returns non-200.

### Story 4 — Connection wizard UX (Standard, ~4h)
Multi-step wizard at `/dashboard/connect` (already exists as a route — needs content).

**Step 1 — OpenClaw gateway**
- Input: gateway URL + bearer token
- Action: call `POST /api/gateway` (already exists) 
- On success: save, show green checkmark

**Step 2 — AiPipe routing**
- Show: "AiPipe is active — your requests are now routed to the cheapest model"
- Show: AiPipe health status (green/red)
- Show: estimated savings rate (30% default from settings)
- Action: "Enable routing" → POST to `/api/settings` with `aipipe.enabled: true`

**Step 3 — Provider keys**
- Inputs: OpenAI key, Anthropic key, xAI key (optional, 1+ required)
- These are the TENANT's keys that get stored encrypted in settings (tenantSettings)
- On save: test each key with AiPipe's `/healthz` endpoint

**Step 4 — Done**
- Summary: gateway connected ✅, AiPipe routing ✅, X providers configured
- CTA: "Go to dashboard" + link to Strategos plan if on free tier

### Story 5 — Regression + docs (Quick, ~1h)
- Add to regression suite: AiPipe healthz check, stats endpoint format validation
- Add `docs/features/aipipe-integration.md` + `docs/technical/aipipe-integration.md`
- Update sprint.json with `docsRequired: true, docSlug: "aipipe-integration"`
- Update `HEARTBEAT.md` to check AiPipe process

---

## What We Are NOT Building

- Per-tenant API key isolation in AiPipe itself (single shared key pool, server-side)
- AiPipe public endpoint (stays on 127.0.0.1, MC is the gateway)
- Streaming passthrough in MC proxy routes (body buffering only — per existing AiPipe behavior)
- fasthttp upgrade (stdlib is fine for MVP scale)
- AiPipe admin UI (stats widget in MC covers this)
- Multi-instance AiPipe (single process, single host)

---

## Implementation Order

1. Story 1 (service deploy) — unblocks all others, ~1h
2. Stories 2 + 3 in parallel — MC API routes + stats widget, ~3-4h each
3. Story 4 (wizard) — depends on story 2 for gateway step, ~4h
4. Story 5 (regression + docs) — last, ~1h

---

## Red Flags

- AiPipe `/healthz` returns non-200 after deploy → check env vars (need at least 1 API key)
- Settings encryption: tenant API keys must NOT be stored plaintext in DB — use existing `tenantSettings` JSON blob (encrypted at rest by Postgres, not extra encryption needed for MVP)
- The `/dashboard/connect` page currently exists but shows placeholder — must not break existing Coolify env regression check
- If AiPipe URL is unreachable from MC: `/api/aipipe/*` routes return 503 with `{ error: "AiPipe unavailable" }` — never 500

---

## Sprint.json Classification

Stories 1 and 5 → Quick → AUTO once epic is active  
Stories 2, 3, 4 → Standard → need specPath set → AUTO once spec exists  

Epic status: `backlog` → needs Mike to activate → set to `in_progress`
