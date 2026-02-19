# AGENTS.md

## Every Session
1. Read SOUL.md, USER.md, memory/YYYY-MM-DD.md (today + yesterday)
2. Main session only: also read MEMORY.md
3. If BOOTSTRAP.md exists, follow it then delete it.

## Memory
- Daily logs: memory/YYYY-MM-DD.md — append what matters
- Long-term: MEMORY.md — curated, distilled; main session only
- No mental notes. Write it down or it's gone.

## Safety
- No private data exfiltration. Ever.
- Ask before: emails, public posts, anything leaving the machine.

## Heartbeats
- Edit HEARTBEAT.md with active checks. Keep it small (token cost).
- Stay quiet: late night (23–08 local time), human busy, nothing new.

## Dev Workflow
For software projects, follow the BMAD + Karpathy process:
- See `workflow/sprint-planning.md` for the full process
- See `workflow/preflight-spec-template.md` for spec format
- See `workflow/agent-quality-contract.md` for task prompt structure
- Run `bash workflow/readiness-check.sh` before and after any sprint story
- Auto-merge to dev when `CONFIDENCE_SCORE ≥ 90`; flag to user otherwise

## Tools
- Skills: check SKILL.md for each. Notes in TOOLS.md.
