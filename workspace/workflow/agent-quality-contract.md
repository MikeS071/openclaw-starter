# Agent Quality Contract
_Every subagent task prompt MUST include these elements (agentic engineering has craft)_

## Mandatory Task Prompt Structure

```
## Context
[1-2 sentences: what the system does, current state]

## Pre-flight Spec
[Full content of the pre-flight spec for this feature]

## Your Task
[Specific, scoped work — story-level, not feature-level]

## Quality Rules (non-negotiable)
1. BUILD: Run `npx next build` (background + wait). Commit only if exit 0.
   If build fails due to YOUR changes: fix before committing.
   If build fails due to pre-existing issues: note explicitly, do NOT include in commit.
2. TESTS: Run `bash scripts/test-<feature>.sh http://127.0.0.1:3003` against live server.
   All tests must pass (0 failures). Fix failures before committing.
3. SCOPE: Modify only files listed in the pre-flight spec.
   Do NOT modify start-dev.sh, start.sh, .env files, or unrelated components.
4. SCHEMA: If adding DB columns, update BOTH schema.ts AND the migration SQL.
   Migration must match schema.ts exactly.
5. COMMIT: Single focused commit. Message: "<verb> <feature>: <what changed>"
   Do NOT include unrelated modified files.

## Validation Checklist (report each)
- [ ] schema.ts matches migration SQL (if DB changes)
- [ ] All new API routes have corresponding test cases
- [ ] Build exit code: 0
- [ ] Test results: X passed, 0 failed
- [ ] Files modified: [list]
- [ ] Commit hash: [hash]
- [ ] Branch pushed: origin/feature/xxx
```

## Principles Applied
- **Context is the program**: pre-flight spec goes in the prompt, not "figure it out"
- **Stochastic systems**: explicit rules prevent agent drift into unrelated files
- **Quality without compromise**: build + tests are gates, not suggestions
- **Verify empirically**: test script runs against live server, not mocked
- **Design for failure**: pre-existing failures must be named, not hidden in the diff

## Story Sizing
- **Quick** (< 30min agent time): 1-2 API routes, no DB changes, UI tweak
- **Standard** (30-60min): DB + API + UI, single coherent feature
- **Split required** (> 3 API routes OR > 1 table change): decompose into stories A/B/C

## Phase 5: Documentation + Landing/Roadmap Update (after every feature merge)

After a feature merges to dev (and before prod release), run a doc agent with this task:

### User Docs
- `docs/features/<feature-name>.md` — plain English: what it does, how to use it, screenshots/curl examples
- Update `docs/README.md` index if new doc added
- Audience: non-technical users / future customers onboarding

### Technical Docs
- `docs/technical/<feature-name>.md` — API reference (endpoint, auth, request, response, errors), DB schema additions, env vars added, known limitations
- Audience: developers integrating via API or contributing

### Landing Page (`src/app/page.tsx`)
- Does this feature belong in the feature tiles? If yes: add/update tile with icon + 1-line description
- Does this feature change the value prop? If yes: update hero copy
- Rule: only update if the feature is user-visible and customer-relevant

### Roadmap Page (`src/app/roadmap/page.tsx`)
- Move the feature from "In Progress" → "Delivered" with the shipped date
- Add any newly-started features to "In Progress"
- Rule: roadmap must always reflect current reality, not aspirational state

### Doc agent task prompt template
```
You are writing documentation for feature: <name>
Branch: <branch> | Commit: <hash>

Pre-flight spec (for context): <paste spec>

Tasks:
1. Write docs/features/<feature>.md (user docs — plain English, examples)
2. Write docs/technical/<feature>.md (API reference, schema changes, env vars)
3. Review src/app/page.tsx — update feature tiles if feature is user-visible
4. Review src/app/roadmap/page.tsx — move feature to Delivered, update In Progress
5. Commit all changes: "docs: add user+technical docs for <feature>; update landing+roadmap"
6. Push to same feature branch (or to dev if already merged)

Quality rules: no broken links, no placeholder text, curl examples must use real endpoint shapes from the pre-flight spec.
```

## What NOT to do
- ❌ "Build the entire wizard feature" (too vague, too large)
- ❌ Omitting schema.ts from the prompt context
- ❌ Accepting a build failure as "pre-existing" without verifying it was pre-existing
- ❌ Launching 3 agents simultaneously when story B depends on story A's schema
- ❌ Shipping a feature without docs — undocumented features don't compound
