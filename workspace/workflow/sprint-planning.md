# Sprint Planning Guide (BMAD + Karpathy Workflow)

This is the full dev process for working with your OpenClaw agent on software projects.

## Overview

```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5
Pre-flight  Stories   Readiness  Sprint    Quality   Docs +
Spec        (complex) Check      Execution Contract  Landing
```

---

## Phase 0: Pre-flight Spec

Before any code is written, create a spec using `preflight-spec-template.md`.

**Why**: Context is the program. An agent with a clear spec drifts less, ships faster, and breaks fewer things.

**Rule**: No code without a spec. No spec = no story = no sprint.

---

## Phase 1: Story Decomposition (complex features only)

If the feature has >3 API routes OR >1 DB table change, split into stories A/B/C.

- Story A: schema + migration
- Story B: API routes + tests (depends on A)
- Story C: UI components (depends on B)

Dependency-free stories can run in parallel. Dependent stories must be sequential.

---

## Phase 2: Readiness Check (pre-sprint)

Run `bash workflow/readiness-check.sh` before starting the sprint.

- Confirms the server is reachable
- Confirms test scripts exist
- Confirms git state is clean
- Outputs `CONFIDENCE_SCORE` and `AUTO_MERGE` flag

---

## Phase 3: Sprint Execution

### Monday Sprint Ritual
1. Agent proposes sprint plan (stories + scope + estimates)
2. User approves once → all stories in the plan are pre-cleared
3. Agent executes all dependency-free stories in parallel
4. User only re-engages if confidence gate fails

### Auto-merge to dev
If after a story completes:
- Build exits 0 ✅
- Tests: 0 failures ✅
- `CONFIDENCE_SCORE ≥ 90` ✅
- Scope matches pre-flight spec ✅

→ Agent merges to `dev` automatically and notifies passively.

If `CONFIDENCE_SCORE < 90`:
→ Agent flags to user with breakdown, waits for explicit approval.

### User touchpoints (3 max per sprint)
1. Monday: approve sprint plan
2. Prod release: approve dev → main
3. Confidence-flagged stories: explicit approval

---

## Phase 4: Agent Quality Contract

See `agent-quality-contract.md` for the full prompt template.

**Every agent task must include**:
- Context (what the system does)
- Full pre-flight spec
- Scoped task (story-level, not feature-level)
- Quality rules (build gate, test gate, scope fence, schema rule, commit rule)
- Validation checklist

---

## Phase 5: Documentation + Landing/Roadmap Update

**Mandatory after every feature merge.**

Docs that don't exist don't compound. Every shipped feature needs:

1. `docs/features/<name>.md` — user docs (plain English, examples)
2. `docs/technical/<name>.md` — API reference, schema changes, env vars
3. Landing page review — add feature tile if customer-relevant
4. Roadmap update — move to Delivered, update In Progress

Use the doc agent template in `agent-quality-contract.md`.

---

## Confidence Gate Reference

| Score | Status | Action |
|-------|--------|--------|
| 90–100 | 🟢 AUTO_MERGE=yes | Merge to dev automatically |
| 75–89 | 🟡 AUTO_MERGE=no | Flag to user, summarise warnings |
| 0–74 | 🔴 AUTO_MERGE=no | Fix failures, re-run check |

Score deductions: -20 per failure, -5 per warning.

---

## Quick Start

```bash
# 1. Create pre-flight spec
cp workflow/preflight-spec-template.md workflow/specs/feature-name.md
# fill in the spec

# 2. Run readiness check before sprint
bash workflow/readiness-check.sh

# 3. After story completes, run readiness check again
bash workflow/readiness-check.sh
# If AUTO_MERGE=yes → merge to dev
# If AUTO_MERGE=no → review output, fix or flag to user
```
