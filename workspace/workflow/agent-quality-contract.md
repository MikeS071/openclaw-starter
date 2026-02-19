# Agent Quality Contract
_Every subagent task prompt MUST include these elements (Karpathy: "agentic engineering has craft")_

## Mandatory Task Prompt Structure

```
## Context
[1-2 sentences: what the system does, current state]

## Pre-flight Spec
[Full content of the pre-flight spec for this feature]

## Your Task
[Specific, scoped work — story-level, not feature-level]

## Quality Rules (non-negotiable)
1. BUILD: Run build command (e.g. `npx next build`). Commit only if exit 0.
   If build fails due to YOUR changes: fix before committing.
   If build fails due to pre-existing issues: note explicitly, do NOT include in commit.
2. TESTS: Run test scripts against live server.
   All tests must pass (0 failures). Fix failures before committing.
3. SCOPE: Modify only files listed in the pre-flight spec.
   Do NOT modify start scripts, .env files, or unrelated components.
4. SCHEMA: If adding DB columns, update BOTH schema AND migration SQL.
   Migration must match schema exactly.
5. COMMIT: Single focused commit. Message: "<verb> <feature>: <what changed>"
   Do NOT include unrelated modified files.

## Validation Checklist (report each)
- [ ] schema matches migration (if DB changes)
- [ ] All new API routes have corresponding test cases
- [ ] Build exit code: 0
- [ ] Test results: X passed, 0 failed
- [ ] Files modified: [list]
- [ ] Commit hash: [hash]
- [ ] Branch pushed: origin/feature/xxx
```

## Karpathy Principles Applied
- **Context is the program**: pre-flight spec goes in the prompt, not "figure it out"
- **Stochastic systems**: explicit rules prevent agent drift into unrelated files
- **Quality without compromise**: build + tests are gates, not suggestions
- **Verify empirically**: test scripts run against live server, not mocked
- **Design for failure**: pre-existing failures must be named, not hidden in the diff

## Story Sizing
- **Quick** (< 30min agent time): 1-2 API routes, no DB changes, UI tweak
- **Standard** (30-60min): DB + API + UI, single coherent feature
- **Split required** (> 3 API routes OR > 1 table change): decompose into stories A/B/C

## Confidence Gate (auto-merge to dev)
After any feature build, run `bash scripts/readiness-check.sh`:
- `CONFIDENCE_SCORE ≥ 90` + `AUTO_MERGE=yes` → auto-merge to dev
- `CONFIDENCE_SCORE < 90` → flag to user with breakdown, wait for approval

## Phase 5: Documentation + Landing/Roadmap Update
_Shipped features that nobody knows about don't compound._

After a feature merges to dev (and before prod release):

### User Docs
- `docs/features/<feature-name>.md` — plain English: what it does, how to use it, examples
- Audience: non-technical users / future customers onboarding

### Technical Docs
- `docs/technical/<feature-name>.md` — API reference, schema additions, env vars, limitations
- Audience: developers integrating via API or contributing

### Landing Page
- Does this feature belong in the feature tiles? Add/update if user-visible and customer-relevant.

### Roadmap
- Move the feature from "In Progress" → "Delivered" with the shipped date.
- Roadmap must always reflect current reality.

### Doc agent task prompt template
```
You are writing documentation for feature: <name>
Branch: <branch> | Commit: <hash>

Pre-flight spec (for context): <paste spec>

Tasks:
1. Write docs/features/<feature>.md (user docs — plain English, examples)
2. Write docs/technical/<feature>.md (API reference, schema changes, env vars)
3. Review landing page — update feature tiles if feature is user-visible
4. Review roadmap — move feature to Delivered, update In Progress
5. Commit: "docs: add user+technical docs for <feature>; update landing+roadmap"

Quality rules: no broken links, no placeholder text, curl examples must use real endpoint shapes.
```

## What NOT to do
- ❌ "Build the entire feature" (too vague, too large)
- ❌ Omitting schema from the prompt context
- ❌ Accepting a build failure as "pre-existing" without verifying
- ❌ Launching dependent stories in parallel (story B needs story A's schema)
- ❌ Shipping a feature without docs — undocumented features don't compound
