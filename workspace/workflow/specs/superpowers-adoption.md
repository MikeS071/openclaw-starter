# Superpowers → Archon Workflow Mapping
_Author: Navi | Date: 2026-02-23 | Status: Adopt (partial)_

## Why this exists
We reviewed obra/superpowers (agentic skills framework + development methodology). The recommendation is **not** to adopt Superpowers wholesale as the canonical workflow, because Archon already has a stronger, platform-oriented process (sprint.json, AUTO/NEEDS_USER classification, dev→main hard gate, docs gate).

Instead we adopt **specific high-signal practices** and encode them into our existing workflow artifacts under `workflow/`.

## Summary decision
- **Canonical workflow remains ours** (`WORKFLOW_AUTO.md`, Sprint phases, docs gate, release gate).
- Adopt these Superpowers components:
  1) Systematic debugging
  2) Verification-before-completion
  3) Plan granularity standard (2–5 min tasks with explicit commands)
  4) Review rubric (severity-tiered, scope compliance, verification evidence)

## What we already have (keep)
- Phase 0.5 PRD approval gate (SOUL.md)
- Phase 5 docs gate (SOUL.md + navi-ops)
- Release gate: **never dev→main without explicit Mike approval**
- Agent Quality Contract: `workflow/agent-quality-contract.md`

## What we adopt (and where it lives)

### 1) Systematic Debugging (new template)
**Intent:** eliminate ad-hoc guessing. Force evidence gathering and hypothesis testing.

**We adopt:** a 4-phase loop:
1. Repro + baseline
2. Instrument + observe
3. Narrow hypothesis + minimal fix
4. Verify + regress

**Workspace location:** `workflow/templates/systematic-debugging.md`

**When to use:** any recurring bug, flake, performance regression, or “it reloads every 60s” class issues.

### 2) Verification Before Completion (new checklist)
**Intent:** reduce “done but not actually” outcomes.

**We adopt:** before marking a story done, record:
- exact command(s) run
- expected output
- actual output / screenshot
- negative test (what should NOT happen)

**Workspace location:** `workflow/templates/verification-before-completion.md`

### 3) Plan granularity standard (tighten our plan template)
**Intent:** plans should be executable by a junior engineer with zero context.

**We adopt:** every plan task includes:
- timebox (2–5 min)
- file paths
- copy/paste commands
- acceptance criteria
- verification steps

**Workspace location:** update `workflow/preflight-spec-template.md` (add plan section) and/or add `workflow/templates/plan-task.md`.

### 4) Review rubric (add a standard reviewer checklist)
**Intent:** consistent reviews across subagents/humans.

**We adopt:** severity tiers + scope compliance + proof.

**Workspace location:** `workflow/templates/review-rubric.md`

## Integration with navi-ops
- `navi-ops` subagent prompts already include the Quality Contract. We extend that contract to reference:
  - systematic debugging template (for bug tasks)
  - verification checklist (required in completion summaries)
  - review rubric (required for reviewer role)

## Implementation checklist (docs-only)
- [ ] Add templates under `workflow/templates/`
- [ ] Update `workflow/agent-quality-contract.md` to reference templates
- [ ] (Optional) Update `workflow/preflight-spec-template.md` with plan granularity requirements
- [ ] Sync changes to `openclaw-starter`

## Notes on not adopting wholesale
Superpowers is great craft, but it assumes control over the agent runtime (plugins/marketplaces/worktrees). Archon needs a workflow that is:
- enforceable by automation (cron, navi-ops)
- compatible with OpenClaw skills + subagent orchestration
- aligned with product release/doco gates
