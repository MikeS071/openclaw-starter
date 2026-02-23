# Workflow (OpenClaw Starter)

This folder defines the **canonical process** a new OpenClaw instance boots with.

It is intentionally written for a "new tenant" context:
- minimal assumptions
- explicit gates
- copy/paste runnable steps

## The operating model (short)
1) **PRD first (when needed)** → get explicit approval.
2) **Pre-flight spec** → assumptions + success criteria + scope.
3) **Plan** → tiny tasks (2–5 min) with file paths + commands.
4) **Implement** → smallest diff, test/tsc clean, commit.
5) **Review + verify** → rubric + proof.
6) **Docs gate** (for features) → user + technical docs before release.

## Key files
- `../WORKFLOW_AUTO.md` — what can run autonomously vs needs explicit approval.
- `agent-quality-contract.md` — required structure for sub-agent prompts and quality bars.
- `preflight-spec-template.md` — template for Phase 0 spec.
- `templates/` — adopted Superpowers-derived templates:
  - `systematic-debugging.md`
  - `verification-before-completion.md`
  - `review-rubric.md`
  - `plan-task.md`
- `agents/` — role prompt files for sub-agents.
- `specs/` — long-form technical specs and references.
- `prd/` — PRDs (keep tenant PRDs here).

## PRDs
Store PRDs in: `workflow/prd/<slug>.md`

Use this starter template:
- `workflow/prd/_template.md`
