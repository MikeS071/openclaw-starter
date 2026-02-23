# Pre-flight Spec — ref-6: Unit Test Foundation

**Story ID:** ref-6  
**Type:** Standard  
**Priority:** Medium  
**Effort:** 1 sprint (~8–12h)  
**Risk:** None  
**Date:** 2026-02-20

---

## Assumptions & Ambiguity

1. Test framework: **Jest** + `@testing-library/react` (add if not present). Use `jest.config.ts`.
2. Scope: 4 lib modules — `lib/tenant`, `lib/billing`, `lib/xp`, `lib/streak`. Start here, expand later.
3. Tests go in `src/__tests__/lib/` (co-located by module).
4. We mock DB (`@/lib/db`), external services (Stripe, Resend), and `next/server` — no integration tests.
5. Coverage target: ≥80% line coverage on all 4 lib modules.
6. CI integration: add `jest` to the test script in `package.json`.

---

## Success Criteria

- [ ] `npm test` runs and passes with 0 failures
- [ ] 4 test files exist: `src/__tests__/lib/{tenant,billing,xp,streak}.test.ts`
- [ ] ≥80% line coverage on each of the 4 modules (run `npm test -- --coverage`)
- [ ] Zero TS errors in test files (`npx tsc --noEmit`)
- [ ] Regression suite still passes (tests are additive — must not break anything)

---

## Scope — Modules to Test

### `src/lib/tenant.ts`
Key functions:
- `getTenantId(req)` — unit test: Bearer token match, x-tenant-id header, missing auth → null
- `resolveTenantId(req)` — test fallback paths: email header → DB lookup (mocked), auth() session fallback (mocked)

Mocks needed: `next/server` (NextRequest), `@/lib/db` (db.select)

### `src/lib/billing.ts` (check what's in there)
Likely: plan lookup, subscription checks, Stripe integration helpers.
Mocks needed: `stripe` SDK, `@/lib/db`

### `src/lib/xp.ts`
Functions: `awardXp()`, `XP_RULES` constants, XP calculation logic.
Mocks needed: `@/lib/db`

### `src/lib/streak.ts`
Functions: streak calculation, streak reset logic, date arithmetic.
Mocks needed: `@/lib/db`, `Date` (for time-sensitive tests)

---

## Implementation Steps

### Step 1 — Check/install Jest
```bash
cd /home/openclaw/projects/openclaw-mission-control
cat package.json | grep -E "jest|testing"
```

If not present:
```bash
npm install --save-dev jest @types/jest ts-jest jest-environment-node
```

### Step 2 — jest.config.ts
```typescript
import type { Config } from 'jest'

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
  testMatch: ['**/__tests__/**/*.test.ts'],
  collectCoverageFrom: [
    'src/lib/tenant.ts',
    'src/lib/billing.ts',
    'src/lib/xp.ts',
    'src/lib/streak.ts',
  ],
}

export default config
```

### Step 3 — package.json test script
```json
"test": "jest",
"test:coverage": "jest --coverage"
```

### Step 4 — Write test files (one per module)

Pattern:
```typescript
// src/__tests__/lib/tenant.test.ts
import { getTenantId } from '@/lib/tenant'
// mock next/server NextRequest
// mock @/lib/db

describe('getTenantId', () => {
  it('returns tenantId from Bearer token matching API_SECRET', () => { ... })
  it('returns tenantId from x-tenant-id header', () => { ... })
  it('returns null when no auth present', () => { ... })
  it('returns null for invalid Bearer token', () => { ... })
})
```

### Step 5 — Run and verify coverage
```bash
npm test -- --coverage
```

### Step 6 — Commit
```
test: unit test foundation — lib/tenant, billing, xp, streak (ref-6)
```

---

## Mock Strategy

### Mocking @/lib/db
```typescript
jest.mock('@/lib/db', () => ({
  db: {
    select: jest.fn().mockReturnValue({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([{ tenantId: 1 }]),
        }),
      }),
    }),
  },
}))
```

### Mocking next/server NextRequest
```typescript
function mockRequest(headers: Record<string, string> = {}): Request {
  return {
    headers: { get: (k: string) => headers[k] ?? null },
    nextUrl: { searchParams: new URLSearchParams() },
  } as unknown as Request
}
```

---

## What We Are NOT Building

- E2E or integration tests (that's `regression-test.sh`)
- React component tests (separate story if needed)
- API route tests (regression suite covers those)
- 100% coverage on all files (4 lib modules only for this story)

---

## Red Flags

- `ts-jest` config fails to resolve `@/` path aliases → check `moduleNameMapper` in jest config
- Module has circular imports → mock at module level, not function level
- `lib/billing.ts` requires live Stripe → mock entire stripe module
