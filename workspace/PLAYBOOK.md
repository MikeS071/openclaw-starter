# PLAYBOOK.md — Quick Reference

**Memory Flush Trigger (context ≥ 80%)**
1. Run `session_status` to confirm the percentage.
2. Summarize key active threads/decisions.
3. Append the summary + next steps to today’s `memory/YYYY-MM-DD.md`.
4. Update `MEMORY.md` only if a long-term fact changed.
5. Notify the user that context was flushed and cite the memory entry.

**Spawn a Sub-Agent**
- Command: `sessions_spawn --task "<objective>" --label <short-name> --model <model_id> --runTimeoutSeconds <seconds>`.
- Provide clear scope, exit criteria, and any files/dirs it should use.

**Cron Syntax Examples**
- Every 30 minutes: `openclaw cron add "*/30 * * * *" <command>`
- Daily at 09:00 UTC: `openclaw cron add "0 9 * * *" <command>`
- Weekly Monday 09:00 UTC: `openclaw cron add "0 9 * * 1" <command>`

**Common exec Patterns**
- Run a script: `exec("bash path/to/script.sh")`
- Check running process: `exec("ps aux | grep <name>")`
- Tail logs: `exec("tail -n 200 path/to/log.log")` or `openclaw logs --follow`

**Send Telegram Message Proactively**
- Use `message` tool: `{action:"send", channel:"telegram", target:"<chat_id>", message:"<text>"}`
- Include context, links, and why you’re pinging.

**Using a Skill**
1. Find it in `<available_skills>`.
2. Read its `SKILL.md` start to finish (only one at a time).
3. Follow the instructions precisely.

**Git Workflow Reminder**
- Always create/checkout a feature branch (`git checkout -b feat/...`).
- Never push directly to `main`. Open PRs for review.

**Memory Update Flow**
1. `memory_search` for relevant terms.
2. `memory_get` to read the file before editing.
3. Use `edit`/`write` to update the correct section.

**QA Rules for Any Content**
1. Avoid using dashes as clause separators—use sentences or commas.
2. Write like a human: conversational, concise, empathetic.
3. Do not repeat the same idea or phrase unnecessarily.
