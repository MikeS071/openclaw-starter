---
name: daily-memory
description: "Auto-inject today's and yesterday's memory/YYYY-MM-DD.md into every session bootstrap"
metadata: { "openclaw": { "emoji": "📅", "events": ["agent:bootstrap"] } }
---

# daily-memory hook

Fires on `agent:bootstrap` and pushes today's and yesterday's daily memory log
into `context.bootstrapFiles` so they are auto-injected into every new session —
no manual `memory_get` step required.

## What it does

1. Resolves the workspace `memory/` directory.
2. Converts current UTC time to the local timezone offset configured at the top of `handler.ts`.
3. Reads `memory/YYYY-MM-DD.md` for today and yesterday (silently skips if missing).
4. Pushes each found file into `context.bootstrapFiles` alongside AGENTS.md, SOUL.md, etc.

## Setup

1. Copy this directory into your workspace: `<workspace>/hooks/daily-memory/`
2. Enable the hook: `openclaw hooks enable daily-memory`
3. Restart the gateway: `openclaw gateway restart`
4. Verify in `openclaw hooks list` — should show `✓ ready`.

Optionally adjust `UTC_OFFSET_HOURS` in `handler.ts` to match your local timezone
so "today" resolves correctly.

## Requirements

- Workspace must be configured (`workspace.dir`).
- Memory files must follow the `<workspace>/memory/YYYY-MM-DD.md` naming convention.
