# Pre-flight Spec — [Feature Name]
_Created: YYYY-MM-DD | Branch: feature/xxx | Author: [Agent Name]_

## Summary
One sentence: what this feature does and why it exists.

## DB Changes
<!-- List every schema.ts change and the matching migration SQL -->
```typescript
// schema.ts additions
columnName: type('col_name').default('value'),
```
```sql
-- migration SQL
ALTER TABLE table_name ADD COLUMN IF NOT EXISTS col_name TYPE DEFAULT value;
```
Migration file: `drizzle/migrations/XXXX_feature_name.sql`

## API Endpoints
<!-- One block per endpoint -->
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | /api/xxx | Bearer | Returns ... |
| POST | /api/xxx | Bearer | Creates ... |

Request shape:
```json
{ "field": "type" }
```
Response shape:
```json
{ "field": "type" }
```

## UI Components
<!-- List files added or modified -->
- `src/components/NewComponent.tsx` — purpose
- `src/app/dashboard/page.tsx` — modified: added X import, Y prop

## Acceptance Criteria
<!-- These map 1:1 to test cases in the test script -->
- [ ] AC1: GET /api/xxx returns 200 with shape { ... }
- [ ] AC2: POST /api/xxx creates a record and returns { id, ... }
- [ ] AC3: Cross-tenant isolation: tenant B cannot read tenant A's data
- [ ] AC4: Build passes (`npx next build` exits 0)

## Known Risks / Integration Points
<!-- Things that could go wrong across layers -->
- Depends on: [other feature or table]
- Migration order: run after XXXX
- Edge cases: [describe]

## Story Breakdown (if complex)
<!-- Only for features with >3 API routes or DB changes -->
| Story | Scope | Depends On |
|-------|-------|------------|
| A | schema + migration | — |
| B | API routes + tests | A |
| C | UI components | B |

## Out of Scope
<!-- Explicit boundaries prevent scope creep -->
- Not building: X, Y, Z

## Documentation Plan (Phase 5 — post-merge)
<!-- Filled after feature merges, before prod release -->

### User Docs
- File: `docs/features/<feature-name>.md`
- Key sections: What it does, How to use it, Examples

### Technical Docs
- File: `docs/technical/<feature-name>.md`
- Key sections: API reference, DB schema additions, env vars, limitations

### Landing Page Impact
- [ ] Feature tile: add / update / no change (reason: ___)
- [ ] Hero copy: update / no change (reason: ___)

### Roadmap Impact
- [ ] Move to Delivered: Yes / No
- [ ] New In Progress items: ___
