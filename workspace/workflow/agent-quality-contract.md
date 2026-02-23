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

## Agent Mode (declare at task start)

Every sub-agent task starts in one mode — declare it before doing anything:

- **Development Mode** — implement first, explain after; keep diffs small and atomic; validate every change with runnable checks
- **Research Mode** — gather evidence before editing; confirm assumptions with code/doc inspection; present findings first, recommendations second
- **Review Mode** — prioritize findings by severity: `critical > high > medium > low`; focus on correctness, security, performance regressions, test gaps

## Agent Role (navi-ops assigns one per task)

| Role | Model | Tools | Mode | Responsibility |
|------|-------|-------|------|---------------|
| `architect` | sonnet | Read, Grep, Glob | Research | System design, ADRs, tradeoff analysis — invoked for complex/risky features |
| `planner` | sonnet | Read, Grep, Glob | Research | Pre-flight spec, risk mapping, story decomposition, red-flag scan |
| `code-agent` | gpt-5.3-codex | All | Development | Story implementation — surgical, scoped to spec files |
| `tdd-guide` | gpt-5.3-codex | Read, Write, Edit, Bash, Grep | Development | Test-first for new API routes — writes failing test before code-agent starts |
| `security-reviewer` | sonnet | Read, Bash, Grep, Glob | Review | OWASP Top 10, secrets scan, tenant isolation, auth gates — Approve/Warn/Block verdict |
| `code-reviewer` | sonnet | Read, Grep, Glob, Bash | Review | Scope check, security, quality, performance — Approve/Warn/Block verdict |
| `build-error-resolver` | gpt-5.3-codex | Read, Write, Edit, Bash, Grep, Glob | Development | Minimal-diff TS/build recovery only — no feature changes permitted |
| `doc-updater` | opus | All | Development | Phase 5: user docs, technical docs, roadmap Delivered, landing review |
| `e2e-runner` | sonnet | Read, Write, Edit, Bash, Grep, Glob | Development | Runs regression suite against live dev server, reports pass/fail |
| `refactor-cleaner` | gpt-5.3-codex | Read, Write, Edit, Bash, Grep, Glob | Development | Dead code removal, duplicate consolidation, dep cleanup — never during active dev |

Role definitions: `workflow/agents/<role>.md` — each file is the authoritative prompt for that agent.
navi-ops injects the role file + pre-flight spec into every sub-agent spawn.

## Superpowers-derived templates (adopted)
Use these to keep work systematic and verifiable:
- Debugging: `workflow/templates/systematic-debugging.md`
- Verification: `workflow/templates/verification-before-completion.md`
- Review: `workflow/templates/review-rubric.md`
- Plan tasks: `workflow/templates/plan-task.md`
- Mapping note: `workflow/specs/superpowers-adoption.md`

**For high-risk changes, run in parallel:** `code-reviewer` + `security-reviewer` simultaneously via dispatcher.

## Karpathy Engineering Principles (non-negotiable, pre-coding)
Before writing any code, state:
- **Assumptions:** list anything you're assuming that isn't explicit in the spec
- **Ambiguity:** flag any requirement that could be interpreted multiple ways — resolve before coding, not after
- **Success criteria:** restate the acceptance criteria in your own words — if you can't, stop and ask
- **Scope boundary:** explicitly state what you are NOT building in this story

## Quality Rules (non-negotiable)
1. **BUILD:** Run `npx next build` (background + wait). Commit only if exit 0.
   If build fails due to YOUR changes: fix before committing.
   If build fails due to pre-existing issues: note explicitly, do NOT include in commit.
2. **TESTS:** Run `bash scripts/regression-test.sh http://127.0.0.1:3003` against live server.
   All tests must pass (0 failures). Fix failures before committing.
   **Do NOT start the next story while any test is failing. No exceptions.**
3. **SCOPE:** Modify only files listed in the pre-flight spec.
   Do NOT modify start-dev.sh, start.sh, .env files, or unrelated components.
   If you need to touch an unlisted file: stop and flag it — do not proceed silently.
4. **SCHEMA:** If adding DB columns, update BOTH schema.ts AND the migration SQL.
   Migration must match schema.ts exactly.
5. **COMMIT:** Single focused commit. Message: `<verb> <feature>: <what changed>`
   Do NOT include unrelated modified files.
6. **SIMPLICITY:** Implement the smallest solution that satisfies the acceptance criteria.
   If you find yourself adding a helper, abstraction, or table not in the preflight spec — stop and flag it.
7. **FILE SIZE:** Target 200–400 lines per file. Hard stop at 800 — split before committing.
   New components must be in their own file, not appended to an existing one.
8. **ERROR HANDLING:** Every async call, DB query, and external API call must have explicit error handling.
   No silent catch blocks. Log or return the error — never swallow it.
9. **INPUT VALIDATION:** Validate all external input (API request bodies, URL params, webhook payloads) at the route boundary before passing to business logic.
10. **IMMUTABILITY:** Prefer immutable data patterns. No in-place mutation of shared objects across async boundaries. Use spread/map/filter over push/splice/assign on shared state.
11. **SECRETS:** Zero hardcoded secrets. All config via environment variables (process.env.XYZ). Read from pass store at startup if needed.
12. **PARALLELISM:** Use parallel execution (dispatcher jobs, concurrent sub-agents) for independent tasks. Never run sequential chains when tasks don't depend on each other.

## TDD Workflow (default for new API routes)

1. Write failing test first (add to `scripts/regression-test.sh` or dedicated test)
2. Implement minimal code to make it pass
3. Refactor safely — no behaviour change
4. Re-run full regression suite
5. Verify coverage: all new routes have at least one test case

## Verification Pipeline (run in this order, gate on each step)

1. **Format** — `npx prettier --check src/` (no style debate)
2. **Build** — `npx next build` — exit 0 required
3. **Static analysis** — `npx tsc --noEmit` — 0 errors required
4. **Tests** — `bash scripts/regression-test.sh` — 0 failures required
5. **Security** — grep scan: no hardcoded secrets, no `localhost:PORT` in src, `npm audit` for new deps
6. **Smoke** — `curl archonhq.ai` and `curl dev.archonhq.ai` — both 200

All steps must pass. A failure at any step blocks the commit. Fix before proceeding — do not skip.

## Security Baseline (before any commit)

- No hardcoded keys/tokens/passwords
- Input validation on all public API interfaces
- AuthN/AuthZ enforced on tenant-sensitive endpoints
- Error responses must not leak secrets or internals

**If a security issue is found:**
1. Stop and contain — do not commit anything
2. Fix the critical exposure first
3. Rotate affected secrets (update pass store + Coolify)
4. Scan adjacent code for similar patterns before declaring fixed

## Validation Checklist (report each)
- [ ] schema.ts matches migration SQL (if DB changes)
- [ ] All new API routes have corresponding test cases
- [ ] Verification pipeline: all 6 steps passed
- [ ] Files modified: [list]
- [ ] No file in scope exceeds 800 lines
- [ ] All external inputs validated at boundaries
- [ ] No hardcoded secrets (grep clean)
- [ ] Commit uses conventional format: `feat:/fix:/perf:/docs:/test:/chore:/ci:`
- [ ] Commit hash: [hash]
- [ ] Branch pushed: origin/feature/xxx

## Checkpoint Report (publish after every story/gap — mandatory)
```
✅ Checkpoint: <story name>
Achievements:
• <what was built — 1 line>
• <key decision or tradeoff — 1 line>
Progress: X% complete (<n> of <total> stories done)
LOC: ~<N> lines added/modified
Quality gates: build ✅ | tsc ✅ | tests X/X ✅ | security ✅
```

## Completion Checklist (before declaring any story done)
- [ ] All acceptance criteria from pre-flight spec addressed
- [ ] Security sanity check completed (see Security Baseline)
- [ ] Verification pipeline fully passed (all 6 steps)
- [ ] Phase 5 doc-updater queued or complete: `docs/features/`, `docs/technical/`, roadmap Delivered, landing reviewed
- [ ] Risks, assumptions, and next steps stated in checkpoint
- [ ] Conventional commit pushed to branch
- [ ] Checkpoint summary posted (achievements + % + LOC + quality gates)

**No story is "done" until this checklist is complete.**

## Karpathy Principles Applied
- **Think before coding**: state assumptions and ambiguity up front — no silent guesses
- **Context is the program**: pre-flight spec goes in the prompt, not "figure it out"
- **Simplicity first**: smallest solution that meets requirements; state what you are NOT building
- **Surgical changes**: only touch scope-required code — drift into unrelated files is a bug
- **Goal-driven execution**: define success criteria before implementation
- **Test rigor before progress**: no next feature while tests fail — regression is a hard gate
- **Checkpoint discipline**: after each story/gap publish progress bullets + % + LOC + test count
- **Stochastic systems**: explicit rules prevent agent drift into unrelated files
- **Quality without compromise**: build + tests are gates, not suggestions
- **Verify empirically**: test script runs against live server, not mocked
- **Design for failure**: pre-existing failures must be named, not hidden in the diff
- **Parallel by default**: independent tasks run concurrently via dispatcher/sub-agents

## Story Sizing
- **Quick** (< 30min agent time): 1-2 API routes, no DB changes, UI tweak
- **Standard** (30-60min): DB + API + UI, single coherent feature
- **Split required** (> 3 API routes OR > 1 table change): decompose into stories A/B/C

## Phase 5: Documentation + Landing/Roadmap Update ⛔ HARD GATE — required before dev → main

_Karpathy: "claim the leverage" — shipped features that nobody knows about don't compound._

**Timing:** Phase 5 runs after a feature merges to `dev` and **must be complete before `navi-ops release check` will pass**. No feature reaches prod undocumented. The doc gate is not a courtesy — it is a merge blocker.

**Who runs it:** `navi-ops release docs` auto-spawns a `doc-updater` sub-agent (sonnet, Development Mode) for any feature that is missing docs. Mike is not asked — it runs automatically. If the agent fails or produces output needing review, Mike is alerted.

**`--skip-docs` override:** allowed only with an explicit written reason, logged to audit trail with timestamp.

After a feature merges to dev, the `doc-updater` agent runs this task:

### User Docs
- `docs/features/<feature-name>.md` — plain English: what it does, how to use it, screenshots/curl examples
- Update `docs/README.md` index if new doc added
- Audience: non-technical users / future customers onboarding

### Technical Docs
- `docs/technical/<feature-name>.md` — API reference (endpoint, auth, request, response, errors), DB schema additions, env vars added, known limitations
- Audience: developers integrating via API or contributing to MC

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

## Non-Negotiables (from AiPipe AGENTS.md §14 + Mike 2026-02-20)
- No feature is complete without passing tests — no exceptions
- No security-sensitive change without explicit security reviewer pass
- No move to next story without checkpoint summary
- No mixing unrelated cleanup with behaviour changes in a single commit
- No dev → main merge without Phase 5 complete: user docs + technical docs + roadmap updated + landing reviewed

## What NOT to do
- ❌ "Build the entire wizard feature" (too vague, too large)
- ❌ Omitting schema.ts from the prompt context
- ❌ Accepting a build failure as "pre-existing" without verifying it was pre-existing
- ❌ Launching 3 agents simultaneously when story B depends on story A's schema
- ❌ Shipping a feature without docs — undocumented features don't compound
- ❌ Skipping the verification pipeline steps — all 6 must pass, in order
- ❌ Declaring "done" without the completion checklist
- ❌ Committing without conventional commit prefix (feat:/fix:/perf: etc.)
- ❌ Mixing security fixes with feature code in the same commit
