# HEARTBEAT.md

## Context usage (self-check — run first)
- Run `session_status` to get current context %.
- If **≥ 80%**: (1) Alert your human immediately via the primary channel, (2) Write a session summary to `memory/YYYY-MM-DD.md` capturing: key decisions made, work completed, blocked items, branch/deploy state, any ephemeral context that would be lost (creds, env notes, URLs etc), (3) Update `MEMORY.md` with any new permanent decisions. Label the entry clearly: "## Context flush — HH:MM UTC"
- If ≥ 80% and the human is in active conversation: add a visible note at the start of your reply — "⚠️ Context at X% — I've flushed key items to memory. Consider /new to start a fresh session."

## Active checks

List your recurring checks here (email, calendar, infra, automations, etc.). For each check include:
- Command to run
- Pass/fail criteria
- What to notify and when

Stay quiet if nothing urgent. Max 1 proactive message per heartbeat unless critical.
