# Pre-flight Spec — ref-2: Input Validation (Zod on mutation routes)

**Story ID:** ref-2  
**Type:** Standard  
**Priority:** High  
**Effort:** 6–8h  
**Risk:** Security  
**Date:** 2026-02-20

---

## Assumptions & Ambiguity

1. Only POST/PATCH/DELETE routes that accept a request body need Zod schemas. GET routes reading query params only need basic presence checks (already done where needed).
2. `resolveTenantId()` provides auth — Zod validates shape, not auth.
3. We will use `zod` (already in package.json as a dep via NextAuth).
4. Invalid input → 400 with `{ error: string }` — no exception leakage.
5. We do NOT add Zod to routes that only read from the DB (no body input).
6. **Scope exclusion:** Do NOT touch: auth routes (NextAuth manages), webhook/stripe (has own validation), openapi/docs routes.

---

## Success Criteria

- [ ] Every POST/PATCH/DELETE route that accepts a body has a Zod schema at the top of the handler
- [ ] All invalid inputs return `400 { error: string }` before reaching DB layer
- [ ] Zero new TS errors (`npx tsc --noEmit` passes)
- [ ] Regression suite still passes (`bash scripts/regression-test.sh http://127.0.0.1:3003`)
- [ ] No existing behaviour changed for valid inputs

---

## Scope — Routes to Validate

Identified by audit (29 routes lacking validation). Grouped by file:

### Priority 1 — User-facing mutations (highest risk)

| Route | Method | Body fields to validate |
|-------|--------|------------------------|
| `/api/tasks` | POST | `title: string (1–200)`, `goal?: string`, `priority?: enum`, `status?: enum`, `tags?: string`, `assignedAgent?: string` |
| `/api/tasks/[id]` | PATCH | same as POST (partial) |
| `/api/tasks/[id]` | DELETE | none (id from URL) |
| `/api/events` | POST | `taskId: number`, `type: string (1–80)`, `message?: string` |
| `/api/agent-stats` | POST | `agentId: string`, `model: string`, `inputTokens: number`, `outputTokens: number`, `cost?: number` |

### Priority 2 — Billing / Stripe

| Route | Method | Body fields |
|-------|--------|-------------|
| `/api/billing/checkout` | POST | `plan: enum("strategos","archon")`, `billingCycle: enum("monthly","yearly")` |
| `/api/billing/portal` | POST | none (uses session) |

### Priority 3 — Admin/internal

| Route | Method | Body fields |
|-------|--------|-------------|
| `/api/heartbeat` | POST | `status: string`, `data?: object` |
| `/api/waitlist` | POST | (already has email regex — add Zod to standardise) |

### Out of scope (own validation or no body)
- `webhook/stripe` — Stripe SDK validates
- `webhook/github` — no body parsing
- `auth/*` — NextAuth
- All GET routes

---

## Implementation Steps

### Step 1 — Install/confirm zod available
```bash
cd /home/openclaw/projects/openclaw-mission-control
node -e "require('zod'); console.log('ok')"
```
If missing: `npm install zod`

### Step 2 — Create shared validation helper
File: `src/lib/validate.ts`

```typescript
import { z, ZodSchema } from 'zod'
import { NextResponse } from 'next/server'

export function parseBody<T>(schema: ZodSchema<T>, body: unknown):
  | { ok: true; data: T }
  | { ok: false; response: NextResponse } {
  const result = schema.safeParse(body)
  if (!result.success) {
    return {
      ok: false,
      response: NextResponse.json(
        { error: result.error.issues.map(i => i.message).join('; ') },
        { status: 400 }
      ),
    }
  }
  return { ok: true, data: result.data }
}
```

### Step 3 — Add Zod schemas per route (Priority 1 first, then 2, then 3)

Pattern for each route handler:
```typescript
import { z } from 'zod'
import { parseBody } from '@/lib/validate'

const TaskSchema = z.object({
  title: z.string().min(1).max(200),
  // ... other fields
})

export async function POST(req: NextRequest) {
  const tenantId = await resolveTenantId(req)
  if (!tenantId) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const parsed = parseBody(TaskSchema, await req.json())
  if (!parsed.ok) return parsed.response
  const body = parsed.data
  // ... rest of handler uses body.title etc.
}
```

### Step 4 — Verify
```bash
npx tsc --noEmit
bash scripts/regression-test.sh http://127.0.0.1:3003
```

---

## Testing Strategy

- Regression suite covers happy-path (valid inputs) — must still pass
- Manual smoke: send malformed POST to `/api/tasks` with no title → expect 400
- No unit tests required for this story (ref-6 is the unit test foundation story)

---

## What We Are NOT Building

- Structured logging for validation errors (separate concern)  
- Response body schemas (output validation) — not in scope  
- OpenAPI schema sync — not in scope  
- Runtime schema enforcement middleware — each route handles its own

---

## Red Flags (stop and ask if any of these appear)

- A route has complex nested validation that would take >2h alone → flag, scope individually
- Existing integration test breaks on a valid input shape → revert schema, check assumptions
- `zod` is not available and `npm install zod` fails → flag to Mike

---

## Effort Breakdown

| Group | Routes | Est. time |
|-------|--------|-----------|
| Priority 1 (tasks, events, agent-stats) | 5 | 2–3h |
| Priority 2 (billing) | 2 | 1h |
| Priority 3 (heartbeat, waitlist cleanup) | 2 | 1h |
| validate.ts helper + TS check + regression | — | 1h |
| **Total** | **9** | **5–6h** |
