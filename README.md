# openclaw-starter

Workspace template used by ArchonHQ provisioning. When a new paid tenant is created, the provisioning service copies `workspace/` from this repo into the tenant's fresh OpenClaw instance so they boot with the current Navi persona, working agreements, and runbook scaffolding.

## How provisioning uses this repo
1. Provisioner clones `openclaw-starter` on the control node.
2. `workspace/` is synced into the new tenant's `/home/openclaw/.openclaw/workspace/` before the gateway starts.
3. README + automation assets are referenced for any optional extras (e.g., workflow templates) when enabled.
4. After copy, the tenant customises `USER.md`, `MEMORY.md`, `TOOLS.md`, and any workflow docs during onboarding.

Keep this repo in lockstep with the production Navi workspace. When the main workspace changes, mirror the relevant files here so new tenants inherit the same guardrails and expectations.

## Structure

```
openclaw-starter/
  workspace/
    AGENTS.md
    SOUL.md
    USER.md
    HEARTBEAT.md
    TOOLS.md
    MEMORY.md
    IDENTITY.md
  README.md  ← this file
```

You can add more folders (e.g., `workflow/`, `automation/`) as needed, but the files above are the minimum set provisioned into every tenant.

## Updating the templates
- Make edits in the production workspace first.
- Re-run those edits here, keeping user-specific secrets out of the template.
- Document any required manual steps inside the files themselves.
- When ready, push to the provisioning repo and notify Ops so the next tenant pick-up includes the change.

## Manual use (local install)
If you already have OpenClaw running and just want the latest persona files:

```bash
git clone https://github.com/MikeS071/openclaw-starter.git
cp -R openclaw-starter/workspace/* /home/openclaw/.openclaw/workspace/
```

Review each file after copying and fill in the placeholders before restarting your agent.
