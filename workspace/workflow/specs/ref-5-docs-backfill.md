# Pre-flight Spec — ref-5: Phase 5 Docs Backfill

**Story ID:** ref-5  
**Type:** Standard  
**Priority:** High  
**Effort:** 1 sprint (~8–12h)  
**Risk:** None  
**Date:** 2026-02-20

---

## Assumptions & Ambiguity

1. The docs gate is now sprint.json-driven — we don't need docs for every historical feat: commit. Only features explicitly marked `docsRequired: true` in sprint.json get checked.
2. This story's goal: create `docs/features/` and `docs/technical/` directories and write docs for **the 6 major shipped features** worth documenting for customers and contributors.
3. We will use the doc-updater role (opus model) for each feature doc pair.
4. Docs live in the MC repo at: `docs/features/<slug>.md` and `docs/technical/<slug>.md`
5. After each doc is written, update the sprint item's `docSlug` field and set `docsRequired: true`.

---

## Success Criteria

- [ ] `docs/features/` directory exists in MC repo with ≥6 feature docs
- [ ] `docs/technical/` directory exists with ≥6 matching technical docs
- [ ] `navi-ops release check` Gate 2 passes after sprint.json is updated with `docsRequired: true` + `docSlug` for each documented feature
- [ ] Each doc follows the format defined in `workflow/agents/doc-updater.md`
- [ ] Roadmap page updated — documented features shown as Delivered where applicable

---

## Features to Document (scoped set)

These are the production-shipped features worth Phase 5 docs:

| Slug | Feature | User doc? | Tech doc? |
|------|---------|-----------|-----------|
| `kanban-board` | Kanban Board (tasks, drag/drop, filters, WIP limits) | ✅ | ✅ |
| `activity-feed` | Activity feed + per-card event timeline | ✅ | ✅ |
| `billing-stripe` | Stripe billing (Initiate/Strategos/Archon tiers) | ✅ | ✅ |
| `waitlist` | Waitlist + welcome email + newsletter auto-send | ✅ | ✅ |
| `agent-stats` | Agent cost charts (Agents tab, POST /api/agent-stats) | ✅ | ✅ |
| `navi-ops-cli` | navi-ops CLI (status/plan/release/run) | ✅ | ✅ |

---

## Implementation Steps

### Step 1 — Create directory structure
```bash
mkdir -p /home/openclaw/projects/openclaw-mission-control/docs/features
mkdir -p /home/openclaw/projects/openclaw-mission-control/docs/technical
```

### Step 2 — Write each doc pair (doc-updater role, one at a time)

For each slug in the table above, produce:

**docs/features/{slug}.md** — User-facing:
- What the feature does (1–2 paragraphs)  
- How to use it (step-by-step, screenshots optional)
- Key concepts / terminology
- Limitations / known issues

**docs/technical/{slug}.md** — Engineering:
- Architecture overview (components, data flow)
- Key files and their responsibilities
- DB schema (tables involved)
- API routes (method, path, auth, request/response shape)
- Notable implementation decisions
- How to extend / modify

### Step 3 — Update sprint.json items with docsRequired + docSlug

For each documented feature (if it has a sprint.json item):
```json
"docsRequired": true,
"docSlug": "kanban-board"
```

### Step 4 — Verify gate passes
```bash
navi-ops release check
```
Gate 2 should show: "All 6 documented features present"

### Step 5 — Commit
```
docs: Phase 5 backfill — docs/features/ + docs/technical/ for 6 shipped features (ref-5)
```

---

## Doc Format (from doc-updater.md)

### features/{slug}.md
```markdown
# Feature Name

## Overview
1–2 sentence summary.

## How to use
Step-by-step.

## Key concepts
- Term: definition

## Limitations
- Known issue or gap
```

### technical/{slug}.md
```markdown
# Technical: Feature Name

## Architecture
Diagram or prose.

## Key files
- `path/to/file.ts` — responsibility

## Database
Table: columns relevant to this feature.

## API
| Method | Path | Auth | Description |
|--------|------|------|-------------|

## Implementation notes
Notable decisions.

## Extension points
How to add/change behaviour.
```

---

## What We Are NOT Building

- Docs for cosmetic changes (rename commits, CSS tweaks)
- OpenAPI spec sync (separate)
- Video walkthroughs
- Docs for features still in development

---

## Red Flags

- Doc takes >2h for a single feature → break into its own story
- Feature is too complex to document accurately without reading entire file → do architecture overview, note gaps
