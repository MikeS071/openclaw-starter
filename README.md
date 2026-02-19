# openclaw-starter

> One command to clone a productive AI assistant on a fresh VPS.

## Quick Start (Fresh VPS)

```bash
curl -fsSL https://raw.githubusercontent.com/MikeS071/openclaw-starter/main/vps-install.sh | sudo bash
```

Installs OpenClaw + security hardening + your AI persona + workflow templates. ~5 minutes on Ubuntu 22.04/24.04.

## What You Get

- OpenClaw installed and running as a systemd user service
- UFW firewall + Fail2ban + Tailscale VPN
- Structured AI persona (`SOUL.md`, `USER.md`, `AGENTS.md`, `IDENTITY.md`)
- Agentic engineering workflow (pre-flight specs, agent quality contract, readiness checks)
- Gmail/Calendar pre-cache automation scaffolding
- Weekly self-improvement cron-friendly templates
- `ocl` management CLI

## Already Have OpenClaw? (Persona Only)

```bash
git clone https://github.com/MikeS071/openclaw-starter.git
cd openclaw-starter
bash install.sh
```

## First-Time Setup (after install)

Configure OpenClaw with your LLM provider, then start the gateway:

```bash
# Configure auth (non-interactive, VPS/headless):
openclaw onboard --non-interactive --accept-risk --auth-choice openai-api-key
# Or for Anthropic API key:
# openclaw onboard --non-interactive --accept-risk --auth-choice anthropic

# Start gateway (headless / no D-Bus):
nohup openclaw gateway run > /tmp/openclaw-gateway.log 2>&1 &

# Test it's working:
openclaw agent --agent main -m "Say hello"
```

The gateway runs automatically on reboot via the systemd user service set up by `vps-install.sh`.

## Managing Your Installation

After install, use the `ocl` CLI:

```bash
ocl status     # check gateway health
ocl logs       # view recent logs
ocl restart    # restart the gateway
ocl backup     # backup your config
ocl update     # update to latest OpenClaw
ocl harden     # restrict SSH to Tailscale only
ocl persona    # re-run setup wizard
```

## Local Testing (Docker)

```bash
cd docker
docker build -t openclaw-starter-test .
```

## install.sh flags

```bash
bash install.sh --non-interactive --skip-keys --dry-run
```

- `--dry-run`: print what would happen, do not copy files or run setup commands
- `--skip-keys`: skip API key setup (useful for CI)

## Structure

```text
.
├── .github/
│   └── workflows/
│       └── test.yml
├── bin/
│   └── ocl
├── README.md
├── install.sh
├── vps-install.sh
├── automation/
│   ├── README.md
│   └── precache-checks.sh
├── docker/
│   └── Dockerfile
└── workspace/
    ├── AGENTS.md
    ├── HEARTBEAT.md
    ├── IDENTITY.md
    ├── MEMORY.md
    ├── SOUL.md
    ├── TOOLS.md
    ├── USER.md
    └── workflow/
        ├── agent-quality-contract.md
        ├── preflight-spec-template.md
        └── readiness-check.sh
```

## Philosophy

This project is designed for practical, repeatable agent setup rather than one-off prompt hacking. You install a secure runtime, then layer in a structured persona and explicit working agreements so the assistant behaves consistently across sessions. The focus is less on "magic" and more on dependable operation under real production conditions.

The workflow is inspired by BMAD-style agentic engineering: define intent before execution, use quality contracts to constrain behavior, and run readiness checks before shipping changes. That gives you a system that is easier to audit, easier to iterate, and less likely to drift as your assistant grows in capability.
